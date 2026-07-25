{
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
        inherit (lib.rbn) get-secret';
        inherit (lib)
          attrNames
          filter
          replaceStrings
          splitString
          hasInfix
          concatStringsSep
          removeSuffix
          ;
        inherit (builtins) readFile match;

        render =
          file: vars:
          let
            src = readFile file;
            names = attrNames vars;
            unused = filter (n: !(hasInfix "@${n}@" src)) names;
            out = replaceStrings (map (n: "@${n}@") names) (map (n: vars.${n}) names) src;
            leftover = filter (line: match ".*@[a-z0-9-]+@.*" line != null) (splitString "\n" out);
          in
          if unused != [ ] then
            throw "render ${baseNameOf file}: unused vars: ${concatStringsSep ", " unused}"
          else if leftover != [ ] then
            throw "render ${baseNameOf file}: unsubstituted markers: ${concatStringsSep " " leftover}"
          else
            out;

        cilium-manifest = pkgs.writeText "cilium.yaml" (
          render ./manifests/cilium.yaml {
            # every line at the block-scalar depth of `valuesContent: |-`
            values = concatStringsSep "\n    " (
              splitString "\n" (removeSuffix "\n" (readFile ./manifests/cilium-values.yaml))
            );
          }
        );

        flux-instance-manifest = pkgs.writeText "flux-instance.yaml" (
          render ./manifests/flux-instance.yaml { inherit (host) dc-domain; }
        );

      in
      lib.mkMerge [
        (get-secret' config "kubernetes/flux/${host.dc-domain}/age-key")
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

          environment.etc."rancher/k3s/registries.yaml".text = ''
            mirrors:
              docker.io:
                endpoint:
                  - "https://mirror.gcr.io"
          '';
          systemd.services.k3s.restartTriggers = [
            config.environment.etc."rancher/k3s/registries.yaml".text
          ];

          networking.firewall.allowedTCPPorts = [
            6443 # k3s apiserver
            10250 # kubelet
            179 # BGP
            4240 # Cilium Health
            8123 # envoy -> home-assistant
            39501 # Hubitat event-push -> home-assistant
          ];

          sops.templates."flux-agekey.yaml".content = render ./manifests/flux-agekey.yaml {
            agekey = config.sops.placeholder."kubernetes/flux/${host.dc-domain}/age-key";
          };

          system.checks = [
            # added b/c pre-commit hook only covers src/kubernetes/**
            (import ./_bootstrap-checks.nix {
              inherit pkgs cilium-manifest flux-instance-manifest;
            })
          ];

          systemd.services.k3s-seed-secrets = {
            description = "Seed the Flux sops-age decryption key into k3s";
            after = [ "k3s.service" ];
            wants = [ "k3s.service" ];
            wantedBy = [ "multi-user.target" ];
            path = [ pkgs.kubectl ];
            restartTriggers = [ config.sops.templates."flux-agekey.yaml".content ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              Environment = "KUBECONFIG=${config.environment.sessionVariables.KUBECONFIG}";
            };
            script = ''
              until kubectl get --raw /readyz >/dev/null 2>&1; do
                echo "waiting for k3s apiserver..."
                sleep 5
              done
              kubectl apply -f ${config.sops.templates."flux-agekey.yaml".path}
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
  };
}
