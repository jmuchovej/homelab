{ inputs, lib, ... }:
let

  # Deterministic UUID from a seed string (md5 -> 8-4-4-4-12), so the domain
  # and network keep a stable identity across rebuilds without random state.
  mk-uuid =
    s:
    let
      h = builtins.hashString "md5" s;
      sub = a: b: builtins.substring a b h;
    in
    "${sub 0 8}-${sub 8 4}-${sub 12 4}-${sub 16 4}-${sub 20 12}";

  machineconfig = inputs.self + "/src/bootstrap/talos/machineconfig.yaml";
in
{
  flake-file.inputs.nixvirt.url = "github:AshleyYakeley/NixVirt";

  # Parametric Talos Linux KVM guest — one VM per Kubernetes cluster.
  #
  #   includes = [
  #     (<rbn/system/virtualization/talos> {
  #       cluster  = "waypoints.so";
  #       endpoint = "https://10.70.0.10:6443";
  #       bridge   = "br-vlan70";
  #     })
  #   ];
  #
  # The VM is an isolation boundary: a compromise inside the guest cluster must
  # not reach the homelab cluster on the same host. That boundary is the VM
  # itself — the guest is a normal citizen of its own VLAN, reachable on LAN/VPN
  # and free to peer BGP, exactly like the bare-metal clusters. Public exposure
  # is a Cloudflare tunnel dialled from inside, so nothing is port-forwarded.
  #
  # ── How this mirrors the k3s bootstrap ────────────────────────────────
  # k3s: NixOS declares the server, seeds `services.k3s.manifests`, sops-nix
  # drops the Flux age key, and a oneshot applies it once the apiserver answers.
  # Flux owns everything after that.
  #
  # Talos reaches the same seams differently, because the guest is not NixOS:
  # `cluster.inlineManifests` replaces `services.k3s.manifests` (both are applied
  # during bootstrap), and the machine config arrives as a nocloud config drive
  # rather than via `nixos-rebuild`.
  #
  # ── Why the seed ISO is built at activation, not in a derivation ──────
  # The finished machine config carries the cluster PKI, and /nix/store is
  # world-readable. So the non-secret base lives in the store, sops-nix delivers
  # the PKI to /run/secrets, and `talos-seed-<name>` merges them (plus the
  # manifests patch) with `talosctl machineconfig patch`, writing the ISO under
  # /var/lib/libvirt — root-owned and off-store.
  rbn.system._.virtualization._.talos.__functor =
    _self:
    {
      cluster, # cluster identity, e.g. "waypoints.so"
      endpoint, # https://<vm-ip>:6443 — Talos controlPlane endpoint
      bridge, # host bridge for the cluster's VLAN — NOT virbr0/NAT
      name ? "talos-${builtins.replaceStrings [ "." ] [ "-" ] cluster}",
      vcpus ? 4,
      memory ? 8, # GiB
      disk ? "/warp/vms/${name}.qcow2",
      disk-size ? "64G",
      # Applied during Talos bootstrap — the analogue of services.k3s.manifests.
      # Each entry is { name, contents }. Supplied as a patch rather than baked
      # into the template: `render-yaml` can only substitute scalars, so a marker
      # in list position cannot produce a YAML sequence.
      inline-manifests ? [ ],
      # sops key holding the output of `talosctl gen secrets` for this cluster.
      pki-secret ? "kubernetes/talos/${cluster}/pki",
    }:
    { class, ... }:
    if class != "nixos" then
      { }
    else
      {
        nixos =
          {
            config,
            host,
            pkgs,
            ...
          }:
          let
            nixvirt = inputs.nixvirt.lib;

            # Fail at eval with a useful message rather than on `builtins.head
            # null` if the endpoint is malformed.
            endpoint-host =
              let
                m = builtins.match "https://([^:/]+).*" endpoint;
              in
              if m == null then
                throw "talos ${cluster}: endpoint must look like https://<host>:<port>, got ${endpoint}"
              else
                builtins.head m;

            base-config = pkgs.writeText "${name}-machineconfig.yaml" (
              lib.rbn.render-yaml machineconfig {
                inherit cluster endpoint;
                hostname = name;
              }
            );

            # Non-secret, so this one can live in the store. JSON is valid YAML,
            # and talosctl treats a plain object patch as a strategic merge.
            manifests-patch = pkgs.writeText "${name}-manifests-patch.yaml" (
              builtins.toJSON { cluster.inlineManifests = inline-manifests; }
            );

            seed-iso = "/var/lib/libvirt/images/${name}-seed.iso";
            mac-seed = builtins.hashString "md5" name;
            talosctl = lib.getExe pkgs.talosctl;
          in
          {
            imports = [ inputs.nixvirt.nixosModules.default ];

            virtualisation.libvirt = {
              enable = true;
              connections."qemu:///system".domains = [
                {
                  definition = nixvirt.domain.writeXML (
                    nixvirt.domain.templates.linux {
                      inherit name;
                      uuid = mk-uuid "domain-${name}";
                      vcpu = {
                        placement = "static";
                        count = vcpus;
                      };
                      memory = {
                        count = memory;
                        unit = "GiB";
                      };
                      storage_vol = disk;
                      # Rendered as a read-only cdrom — the nocloud config drive
                      # Talos reads at first boot.
                      install_vol = seed-iso;
                      bridge_name = bridge;
                      # Stable MAC so DHCP reservations survive rebuilds.
                      net_iface_mac = "52:54:00:${builtins.substring 0 2 mac-seed}:${builtins.substring 2 2 mac-seed}:${
                        builtins.substring 4 2 mac-seed
                      }";
                    }
                  );
                  # talos-seed-<name> starts it once the ISO and disk exist.
                  active = false;
                }
              ];
            };

            # PKI bundle from `talosctl gen secrets`, generated once out-of-band
            # and committed encrypted. Nix cannot mint it: evaluation is pure and
            # certificate generation is I/O.
            sops.secrets.${pki-secret} = {
              mode = "0400";
              owner = "root";
            };

            systemd.services."talos-seed-${name}" = {
              description = "Build the Talos nocloud seed for ${cluster} and start the guest";
              after = [ "libvirtd.service" ];
              wants = [ "libvirtd.service" ];
              wantedBy = [ "multi-user.target" ];
              path = with pkgs; [
                talosctl
                cdrkit
                qemu-utils
                libvirt
                coreutils
              ];
              restartTriggers = [
                base-config
                manifests-patch
              ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = ''
                set -euo pipefail
                umask 077
                install -d -m 0700 /var/lib/libvirt/images "$(dirname ${disk})"

                work="$(mktemp -d)"
                trap 'rm -rf "$work"' EXIT

                # base + PKI + seed manifests. --patch is a repeatable
                # stringArray, applied in order as strategic merges.
                ${talosctl} machineconfig patch ${base-config} \
                  -p @${config.sops.secrets.${pki-secret}.path} \
                  -p @${manifests-patch} \
                  -o "$work/user-data"

                # nocloud demands the volume label `cidata` and these exact
                # filenames; Talos will not look anywhere else.
                printf 'instance-id: %s\nlocal-hostname: %s\n' ${name} ${name} \
                  > "$work/meta-data"
                genisoimage -quiet -output ${seed-iso} \
                  -volid cidata -joliet -rock "$work/user-data" "$work/meta-data"
                chmod 0400 ${seed-iso}

                [ -f ${disk} ] || qemu-img create -f qcow2 ${disk} ${disk-size}
                virsh --connect qemu:///system start ${name} 2>/dev/null || true
              '';
            };

            # The one irreducibly imperative step, mirroring k3s-seed-secrets:
            # etcd is initialised exactly once. Retrying until Talos reports the
            # cluster already exists makes reruns harmless.
            systemd.services."talos-bootstrap-${name}" = {
              description = "Bootstrap the ${cluster} Talos cluster (once)";
              after = [ "talos-seed-${name}.service" ];
              wants = [ "talos-seed-${name}.service" ];
              wantedBy = [ "multi-user.target" ];
              path = [ pkgs.talosctl ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = ''
                set -uo pipefail
                until out="$(${talosctl} -n ${endpoint-host} bootstrap 2>&1)" \
                  || [[ "$out" == *"AlreadyExists"* ]]; do
                  echo "waiting for Talos apid on ${endpoint-host}: $out"
                  sleep 5
                done
                echo "bootstrapped (or already was): $out"
              '';
            };

            # The rendered base must validate for the system to build. Two
            # deliberate choices here:
            #
            # - `talosctl validate`, not check-jsonschema. The vendored schema's
            #   top level is a `oneOf` over every Talos *document* kind, so a
            #   plain v1alpha1 config scores against sibling branches and
            #   reports nonsense ("machine.network was unexpected"). The schema
            #   is still worth vendoring — it drives the editor modeline — but
            #   it is the wrong tool for a build gate.
            # - throwaway PKI. `validate` rightly rejects a config with no
            #   `machine.ca`, and ours arrives from sops at activation, so the
            #   check mints disposable secrets purely to exercise the merge.
            system.checks = [
              (pkgs.runCommand "check-talos-machineconfig-${name}" { nativeBuildInputs = [ pkgs.talosctl ]; } ''
                cd "$TMPDIR"
                talosctl gen secrets -o secrets.yaml
                talosctl machineconfig patch ${base-config} -p @secrets.yaml -o merged.yaml
                talosctl validate --config merged.yaml --mode metal
                touch "$out"
              '')
            ];

            environment.systemPackages = [ pkgs.talosctl ];

            users.users.${host.primary-user.name}.extraGroups = [
              "libvirtd"
              "kvm"
            ];
          };
      };
}
