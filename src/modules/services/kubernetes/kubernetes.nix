{ inputs, ... }: {
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
          ];

          environment.sessionVariables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

          services.k3s = {
            enable = true;
            role = "server";
            gracefulNodeShutdown.enable = true;

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
              cilium.source = ./manifests/cilium.yaml;
              flux-operator.source = ./manifests/flux-operator.yaml;
              flux-instance.source = ./manifests/flux-instance.yaml;
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

          sops.templates."onepassword-connect.yaml".content = ''
            apiVersion: v1
            kind: Namespace
            metadata:
              name: external-secrets
            ---
            apiVersion: v1
            kind: Secret
            metadata:
              name: onepassword-connect-credentials
              namespace: external-secrets
            type: Opaque
            data:
              # sops value is already base64(1password-credentials.json); `data`
              # expects base64, so the mounted file decodes back to raw JSON.
              1password-credentials.json: ${config.sops.placeholder."1password/connect.json"}
            ---
            apiVersion: v1
            kind: Secret
            metadata:
              name: op-connect-ro
              namespace: external-secrets
            type: Opaque
            stringData:
              token: ${config.sops.placeholder."1password/connect-ro"}
            ---
            apiVersion: v1
            kind: Secret
            metadata:
              name: op-connect-rw
              namespace: external-secrets
            type: Opaque
            stringData:
              token: ${config.sops.placeholder."1password/connect-rw"}
          '';

          sops.templates."cluster-settings.yaml".content =
            let
              substituting-namespaces =
                inputs.import-tree (it: it.withLib lib) (it: it.addPath "${inputs.self}/src/kubernetes/apps")
                  (it: it.initFilter (lib.hasSuffix "/namespace.yaml"))
                  (it: it.filterNot (lib.hasInfix "/_"))
                  (it: it.map (p: baseNameOf (dirOf p)))
                  # .files (not .leafs) forces the read and yields the list
                  (it: it.files);

              mk-settings = ns: ''
                ---
                apiVersion: v1
                kind: Namespace
                metadata:
                  name: ${ns}
                ---
                apiVersion: v1
                kind: Secret
                metadata:
                  name: cluster-settings
                  namespace: ${ns}
                type: Opaque
                stringData:
                  DATACENTER: ${host.datacenter}
                  DC_DOMAIN: ${config.sops.placeholder."${host.datacenter}/domain"}
                  DOMAIN: ${config.sops.placeholder."domain"}
                  ADMIN_CIDR: 10.99.0.0/16
              '';
            in
            lib.concatMapStrings mk-settings substituting-namespaces;

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
        systemd.services.k3s.path = [ pkgs.nvidia-container-toolkit.tools ];
      };
  };
}
