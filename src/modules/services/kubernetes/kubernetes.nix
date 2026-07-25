_: {
  rbn.services._.kubernetes = {
    nixos =
      {
        config,
        pkgs,
        lib,
        host,
        ...
      }:
      let
        inherit (lib.rbn) get-secret get-secret';

        render =
          file: vars:
          let
            src = builtins.readFile file;
            names = lib.attrNames vars;
            unused = lib.filter (n: !(lib.hasInfix "@${n}@" src)) names;
            out = lib.replaceStrings (map (n: "@${n}@") names) (map (n: vars.${n}) names) src;
            leftover = lib.filter (line: builtins.match ".*@[a-z0-9-]+@.*" line != null) (
              lib.splitString "\n" out
            );
          in
          if unused != [ ] then
            throw "render ${baseNameOf file}: unused vars: ${lib.concatStringsSep ", " unused}"
          else if leftover != [ ] then
            throw "render ${baseNameOf file}: unsubstituted markers: ${lib.concatStringsSep " " leftover}"
          else
            out;

        k8s-schemas = pkgs.linkFarm "k8s-bootstrap-schemas" [
          {
            name = "fluxcd.controlplane.io/fluxinstance_v1.json";
            path = ./manifests/schemas/fluxinstance_v1.json;
          }
          {
            name = "helm.cattle.io/helmchart_v1.json";
            path = ./manifests/schemas/helmchart_v1.json;
          }
          {
            name = "namespace-v1.json";
            path = ./manifests/schemas/namespace-v1.json;
          }
        ];

        # every line at the block-scalar depth of `valuesContent: |-`
        indent-block = s: lib.concatStringsSep "\n    " (lib.splitString "\n" (lib.removeSuffix "\n" s));

        cilium-manifest = pkgs.writeText "cilium.yaml" (
          render ./manifests/cilium.yaml {
            values = indent-block (builtins.readFile ./manifests/cilium-values.yaml);
          }
        );

        # rendered per-cluster so the FluxInstance sync path selects this
        # cluster's root by datacenter (src/kubernetes/<datacenter>)
        flux-instance-manifest = pkgs.writeText "flux-instance.yaml" (
          render ./manifests/flux-instance.yaml { inherit (host) datacenter; }
        );
      in
      lib.mkMerge [
        (get-secret config "1password/connect.json" host.datacenter)
        (get-secret config "1password/connect-ro" host.datacenter)
        (get-secret config "1password/connect-rw" host.datacenter)
        (get-secret' config "domain")
        (get-secret' config "${host.datacenter}/domain")
        {
          environment.systemPackages = with pkgs; [
            kubectl
            cilium-cli
            fluxcd
            (pkgs.callPackage ./_seed-pvc.nix { })
          ];

          environment.sessionVariables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

          services.k3s = {
            enable = true;
            role = "server";
            gracefulNodeShutdown.enable = true;

            # every zfs dataset reports POOL-free as available, so kubelet's
            # default disk thresholds (nodefs<10%, imagefs<15%) hold ~324GB of
            # the 2TB pool hostage — 5% (~108GB) is guard enough here
            extraKubeletConfig = {
              evictionHard = {
                "memory.available" = "100Mi";
                "nodefs.available" = "5%";
                "imagefs.available" = "5%";
                "nodefs.inodesFree" = "5%";
              };
            };

            disable = [
              "traefik"
              "servicelb"
              "metrics-server"
              "local-storage"
            ];

            extraFlags = [
              "--flannel-backend=none"
              "--disable-network-policy"
              "--disable-kube-proxy"
              "--cluster-cidr=10.244.0.0/16"
              "--service-cidr=10.96.0.0/16"
              "--cluster-dns=10.96.0.10"
              "--write-kubeconfig-mode=0644"
            ];

            manifests = {
              cilium.source = cilium-manifest;
              flux-operator.source = ./manifests/flux-operator.yaml;
              flux-instance.source = flux-instance-manifest;
            };
          };

          # front docker.io with Google's pull-through cache — Docker Hub
          # (throttling, hung pulls) stops being a single point of failure;
          # cache misses fall straight through to docker.io
          environment.etc."rancher/k3s/registries.yaml".text = ''
            mirrors:
              docker.io:
                endpoint:
                  - "https://mirror.gcr.io"
          '';
          systemd.services.k3s.restartTriggers = [
            config.environment.etc."rancher/k3s/registries.yaml".text
          ];

          # k3s apiserver (6443), kubelet (10250), BGP (179), Cilium health
          # (4240). hostNetwork pods sit behind this firewall too: 8123
          # (envoy → home-assistant) and 39501 (Hubitat event push → HA).
          networking.firewall.allowedTCPPorts = [
            6443
            10250
            179
            4240
            8123
            39501
          ];

          sops.templates."onepassword-connect.yaml".content = render ./manifests/onepassword-connect.yaml {
            connect-credentials = config.sops.placeholder."1password/connect.json";
            ro-token = config.sops.placeholder."1password/connect-ro";
            rw-token = config.sops.placeholder."1password/connect-rw";
          };

          sops.templates."cluster-settings.yaml".content =
            let
              # Namespaces seeded with a cluster-settings Secret. Must track this
              # cluster's Flux selection (core/ + <datacenter>/kustomization.yaml):
              # seed a namespace not deployed → stray empty namespace; deploy one
              # not seeded → its apps' postBuild substitution fails. `external-
              # secrets` is intentionally absent — seeded by the onepassword-
              # connect template above, and needs no DC_DOMAIN vars.
              core-namespaces = [
                "auth"
                "cert-manager"
                "databases"
                "kube-system"
                "network"
              ];
              site-namespaces = {
                da = [
                  "media"
                  "home-automation"
                  "local-ai"
                  "home"
                  "games"
                ];
                en = [ ];
              };
              seed-namespaces = core-namespaces ++ (site-namespaces.${host.datacenter} or [ ]);

              mk-settings =
                ns:
                render ./manifests/cluster-settings.yaml {
                  namespace = ns;
                  inherit (host) datacenter;
                  dc-domain = config.sops.placeholder."${host.datacenter}/domain";
                  domain = config.sops.placeholder."domain";
                };
            in
            lib.concatMapStrings mk-settings seed-namespaces;

          # every bootstrap manifest — static and template-rendered — must
          # satisfy its schema for the system to build. Secrets are skipped
          # (kubeconform can't see through sops placeholders anyway); the
          # pre-commit hook covers src/kubernetes/ only, not these.
          system.checks = [
            (pkgs.runCommand "check-k8s-bootstrap-manifests"
              {
                nativeBuildInputs = [
                  pkgs.kubeconform
                  pkgs.check-jsonschema
                  pkgs.yq-go
                ];
                onepasswordConnect = config.sops.templates."onepassword-connect.yaml".content;
                clusterSettings = config.sops.templates."cluster-settings.yaml".content;
                passAsFile = [
                  "onepasswordConnect"
                  "clusterSettings"
                ];
              }
              ''
                cp "$onepasswordConnectPath" onepassword-connect.yaml
                cp "$clusterSettingsPath" cluster-settings.yaml
                kubeconform -strict -skip Secret \
                  -schema-location '${k8s-schemas}/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
                  -schema-location '${k8s-schemas}/{{.ResourceKind}}{{.KindSuffix}}.json' \
                  -summary \
                  ${cilium-manifest} \
                  ${./manifests/flux-operator.yaml} \
                  ${flux-instance-manifest} \
                  onepassword-connect.yaml cluster-settings.yaml

                # cilium values against the chart's own values schema
                check-jsonschema \
                  --schemafile ${./manifests/schemas/cilium-values.json} \
                  ${./manifests/cilium-values.yaml}

                # the vendored schema must have been refreshed for the pinned
                # chart version, or values validate against a stale schema
                want=$(yq 'select(.kind == "HelmChart") | .spec.version' ${cilium-manifest})
                have=$(yq -p json '."cilium-values.json".version' ${./manifests/schemas/SOURCES.json})
                if [ "$want" != "$have" ]; then
                  echo "cilium chart $want but vendored values schema is for $have —" \
                    "run 'just k8s update-schemas'" >&2
                  exit 1
                fi
                touch "$out"
              ''
            )
          ];

          systemd.services.k3s-seed-secrets = {
            description = "Seed bootstrap secrets (1Password Connect, cluster-settings) into k3s";
            after = [ "k3s.service" ];
            wants = [ "k3s.service" ];
            wantedBy = [ "multi-user.target" ];
            path = [ pkgs.kubectl ];
            # RemainAfterExit oneshots don't rerun on switch — retrigger when
            # a template DEFINITION changes (e.g. a new namespace joins the
            # substituting set); rotated secret VALUES still don't, since
            # placeholders resolve after eval
            restartTriggers = [
              config.sops.templates."onepassword-connect.yaml".content
              config.sops.templates."cluster-settings.yaml".content
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              Environment = "KUBECONFIG=/etc/rancher/k3s/k3s.yaml";
            };
            # apply is idempotent; Namespaces are created first (Flux later
            # adopts them). Secret rotation needs a manual `systemctl restart`.
            script = ''
              until kubectl get --raw /readyz >/dev/null 2>&1; do
                echo "waiting for k3s apiserver..."
                sleep 5
              done
              kubectl apply -f ${config.sops.templates."onepassword-connect.yaml".path}
              kubectl apply -f ${config.sops.templates."cluster-settings.yaml".path}
            '';
          };
        }
      ];

    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          kubectl
          fluxcd
          cilium-cli
          k9s
        ];
      };

    # <rbn/services/kubernetes/nvidia> — GPU hosts opt in. k3s auto-generates
    # the containerd nvidia runtime config only if it finds
    # `nvidia-container-runtime` in $PATH at agent start — NixOS puts it
    # nowhere k3s looks by default.
    _.nvidia.nixos =
      { pkgs, ... }:
      {
        # generates the CDI spec (/var/run/cdi) with nix-store paths at boot —
        # NOT inherited from the virtualization aspect; this sub-aspect must
        # be self-sufficient
        hardware.nvidia-container-toolkit.enable = true;

        systemd.services.k3s.path = [ pkgs.nvidia-container-toolkit.tools ];
        # the runtime's CDI generation dlopens libnvidia-ml — which NixOS
        # keeps in /run/opengl-driver, nowhere a raw binary looks
        systemd.services.k3s.environment.LD_LIBRARY_PATH = "/run/opengl-driver/lib";
        # ... and even then, auto-generated specs embed FHS hook paths
        # (/usr/bin/nvidia-ctk). Use the spec hardware.nvidia-container-toolkit
        # pre-generates at boot with nix-store paths instead. Read per
        # container-create — no k3s restart needed on change.
        environment.etc."nvidia-container-runtime/config.toml".text = ''
          [nvidia-container-runtime]
          mode = "cdi"

          [nvidia-container-runtime.modes.cdi]
          default-kind = "nvidia.com/gpu"
          spec-dirs = ["/var/run/cdi"]
        '';
      };
  };
}
