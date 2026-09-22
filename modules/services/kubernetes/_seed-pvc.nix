# Seed a zfs-localpv PVC from a host directory (migrating NixOS-service state
# into k8s), handling the full consumer lifecycle: flux-suspend + scale down
# whatever mounts the PVC, seed, then restore. Encodes the traps that bit
# plex/home-assistant:
#   - legacy mountpoints: the dataset must be mounted EXPLICITLY (writing to
#     the pool path shadow-writes the parent dataset)
#   - single-mount: waits for the consumer to release the dataset
{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "seed-pvc";
  runtimeInputs = with pkgs; [
    kubectl
    fluxcd
    yq-go
    rsync
  ];
  text = ''
    usage() {
      cat >&2 <<'EOF'
    usage: seed-pvc -n <namespace> -p <pvc> -s <source-dir> [-o uid:gid] [-- rsync args...]

      -n, --namespace   namespace of the PVC
      -p, --pvc         PVC name
      -s, --source      host directory to seed from
      -o, --owner       uid:gid for chown (default: consumer's securityContext,
                        falling back to 0:0)
      --                everything after is passed to rsync

      e.g. seed-pvc -n local-ai -p open-webui-data -s /var/lib/open-webui -- --exclude cache/
    EOF
      exit 2
    }

    ns="" pvc="" src="" owner=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -n|--namespace) ns=$2; shift 2 ;;
        -p|--pvc) pvc=$2; shift 2 ;;
        -s|--source) src=$2; shift 2 ;;
        -o|--owner) owner=$2; shift 2 ;;
        --) shift; break ;;
        -h|--help) usage ;;
        *) echo "✗ unknown argument: $1" >&2; usage ;;
      esac
    done
    [ -n "$ns" ] && [ -n "$pvc" ] && [ -n "$src" ] || usage
    [ -d "$src" ] || { echo "✗ source dir $src does not exist" >&2; exit 1; }

    # mount/zfs/chown need root — re-exec rather than fail halfway through
    if [ "$(id -u)" -ne 0 ]; then
      exec sudo "$0" -n "$ns" -p "$pvc" -s "$src" ''${owner:+-o "$owner"} -- "$@"
    fi

    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    pv=$(kubectl get pvc -n "$ns" "$pvc" -o jsonpath='{.spec.volumeName}')
    [ -n "$pv" ] || { echo "✗ no bound PV for $ns/$pvc" >&2; exit 1; }
    pool=$(kubectl get zfsvolume -n kube-system "$pv" -o jsonpath='{.spec.poolName}')
    dataset="$pool/$pv"

    # workloads mounting this PVC, as kind/name lines
    mapfile -t consumers < <(kubectl get deploy,statefulset -n "$ns" -o json |
      yq -p json ".items[] |
        select([.spec.template.spec.volumes[]?.persistentVolumeClaim.claimName] | contains([\"$pvc\"])) |
        (.kind | downcase) + \"/\" + .metadata.name")

    if [ -z "$owner" ] && [ "''${#consumers[@]}" -gt 0 ]; then
      u=$(kubectl get "''${consumers[0]}" -n "$ns" \
        -o jsonpath='{.spec.template.spec.securityContext.runAsUser}')
      g=$(kubectl get "''${consumers[0]}" -n "$ns" \
        -o jsonpath='{.spec.template.spec.securityContext.fsGroup}')
      owner="''${u:-0}:''${g:-''${u:-0}}"
      echo "· owner defaulted to $owner (from ''${consumers[0]} securityContext)"
    fi
    owner=''${owner:-0:0}

    declare -A replicas
    suspended=""
    tmp=""
    # restore consumers even if the seed dies mid-flight — an interrupted run
    # otherwise strands deployments at 0 replicas, which kstatus calls "Ready"
    cleanup() {
      [ -n "$tmp" ] && mountpoint -q "$tmp" && umount "$tmp" && rmdir "$tmp"
      for c in "''${!replicas[@]}"; do
        kubectl scale "$c" -n "$ns" --replicas="''${replicas[$c]:-1}" || true
      done
      for s in $suspended; do
        flux resume kustomization "''${s%/*}" -n "''${s#*/}" --timeout 5m || true
      done
    }
    trap cleanup EXIT

    for c in "''${consumers[@]}"; do
      replicas[$c]=$(kubectl get "$c" -n "$ns" -o jsonpath='{.spec.replicas}')
      ks=$(kubectl get "$c" -n "$ns" -o jsonpath='{.metadata.labels.kustomize\.toolkit\.fluxcd\.io/name}')
      ksns=$(kubectl get "$c" -n "$ns" -o jsonpath='{.metadata.labels.kustomize\.toolkit\.fluxcd\.io/namespace}')
      if [ -n "$ks" ] && ! grep -q "$ks/$ksns" <<<"$suspended"; then
        flux suspend kustomization "$ks" -n "$ksns"
        suspended="$suspended $ks/$ksns"
      fi
      echo "· scaling $c down (was ''${replicas[$c]:-1})"
      kubectl scale "$c" -n "$ns" --replicas=0
    done

    for _ in $(seq 1 60); do
      [ "$(zfs get -H -o value mounted "$dataset")" = "no" ] && break
      sleep 2
    done
    if [ "$(zfs get -H -o value mounted "$dataset")" != "no" ]; then
      echo "✗ $dataset still mounted after 2m — something else holds it" >&2
      exit 1
    fi

    tmp=$(mktemp -d)
    mount -t zfs "$dataset" "$tmp"

    rsync -a --info=progress2 "$@" "''${src%/}/" "$tmp/"
    chown -R "$owner" "$tmp"

    # cleanup (EXIT trap) unmounts and restores consumers
    echo "✓ seeded $ns/$pvc ($dataset) from $src, owned by $owner"
  '';
}
