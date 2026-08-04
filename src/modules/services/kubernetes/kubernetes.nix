{ inputs, ... }:
let
  bootstrap = "${inputs.self}/src/bootstrap/kubernetes";
in
{
  den.schema.host =
    { lib, ... }:
    let
      inherit (lib) mkOption;
      inherit (lib.types) listOf nullOr str;
    in
    {
      options.kubernetes = {
        server-addr = mkOption {
          type = nullOr str;
          default = null;
          description = ''
            `https://<server>:6443` for agents to join. Required when
            `role = "agent"`, ignored otherwise.
          '';
        };

        extra-tls-sans = mkOption {
          type = listOf str;
          default = [ ];
          description = ''
            Additional names/addresses to put in the apiserver serving cert,
            on top of the ones the server aspect derives (hostname, FQDN,
            ZeroTier overlay address) and the ones k3s adds itself
            (`localhost`, `127.0.0.1`, the node's own IPs, the in-cluster
            service IP). Only needed for names k3s can't know about — a VIP,
            a CNAME, a second overlay.
          '';
        };
      };
    };

  rbn.services._.kubernetes = {
    nixos = { config, pkgs, ... }: {
      services.k3s = {
        enable = true;
        gracefulNodeShutdown.enable = true;

        extraKubeletConfig.evictionHard = {
          "memory.available" = "100Mi";
          "nodefs.available" = "5%";
          "imagefs.available" = "5%";
          "nodefs.inodesFree" = "5%";
        };
      };

      environment.systemPackages = [ pkgs.cilium-cli ];

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
        10250 # kubelet
        179 # BGP
        4240 # Cilium Health
      ];
    };

    _.server.nixos =
      {
        lib,
        host,
        pkgs,
        config,
        ...
      }:
      let
        inherit (lib.rbn) render-yaml;

        topology = lib.rbn.from-yaml (inputs.self + "/src/topology.yaml") { inherit pkgs; };

        # k3s already SANs localhost, 127.0.0.1, the node's own IPs and the
        # in-cluster service IP — which is why agents can join on the raw lab
        # address today. What it can't know is the names we actually want in a
        # kubeconfig: the hostname/FQDN, and the ZeroTier overlay address the
        # control plane is moving to. Without these the cert is valid only for
        # an IP that changes out from under us.
        tls-sans = map (san: "--tls-san=${san}") (
          [ host.hostname ]
          ++ [ "${host.hostname}.${host.dc-domain}" ]
          ++ lib.optional (topology.clients ? ${host.hostname}) topology.clients.${host.hostname}.ip
          ++ host.kubernetes.extra-tls-sans
        );

        cilium-values = builtins.readFile "${bootstrap}/cilium-values.yaml";
        cilium-manifest = pkgs.writeText "cilium.yaml" (
          render-yaml "${bootstrap}/cilium.yaml" {
            values = lib.concatStringsSep "\n    " (lib.splitString "\n" (lib.removeSuffix "\n" cilium-values));
          }
        );

        flux-instance-manifest = pkgs.writeText "flux-instance.yaml" (
          render-yaml "${bootstrap}/flux-instance.yaml" { inherit (host) dc-domain; }
        );
      in
      lib.mkMerge [
        (lib.rbn.get-secret' config "kubernetes/flux/${host.dc-domain}/age-key")
        {
          environment.sessionVariables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
          environment.systemPackages = with pkgs; [
            kubectl
            fluxcd
            (pkgs.callPackage ./_seed-pvc.nix { })
          ];

          services.k3s = {
            role = "server";
            disable = [
              "traefik"
              "servicelb"
              "metrics-server"
              "local-storage"
            ];

            # All server-only. `--disable-kube-proxy` in particular is NOT an
            # agent flag — agents learn it from the node config they fetch from
            # the server, so setting it here covers the whole cluster.
            extraFlags = [
              "--flannel-backend=none"
              "--disable-network-policy"
              "--disable-kube-proxy"
              "--cluster-cidr=10.244.0.0/16"
              "--service-cidr=10.96.0.0/16"
              "--cluster-dns=10.96.0.10"
              "--write-kubeconfig-mode=0644"
            ]
            ++ tls-sans;

            manifests = {
              cilium.source = cilium-manifest;
              flux-operator.source = "${bootstrap}/flux-operator.yaml";
              flux-instance.source = flux-instance-manifest;
            };
          };

          networking.firewall.allowedTCPPorts = [
            6443 # k3s apiserver
            8123 # envoy -> home-assistant
            39501 # Hubitat event-push -> home-assistant
          ];

          system.checks = [
            # added b/c pre-commit hook only covers src/kubernetes/**
            (import "${bootstrap}/checks.nix" {
              inherit
                inputs
                pkgs
                cilium-manifest
                flux-instance-manifest
                ;
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

              # `flux-system` is normally created by helm-controller reconciling
              # the flux-operator HelmChart CR (`createNamespace: true`), which
              # lands well after /readyz goes green — on a fresh cluster it
              # hasn't even pulled the OCI chart yet. Create it ourselves rather
              # than race; `helm --create-namespace` tolerates it existing.
              kubectl create namespace flux-system \
                --dry-run=client -o yaml | kubectl apply -f -

              kubectl apply -f ${config.sops.templates."flux-agekey.yaml".path}
            '';
          };

          sops.templates."flux-agekey.yaml".content = render-yaml "${bootstrap}/flux-agekey.yaml" {
            agekey = config.sops.placeholder."kubernetes/flux/${host.dc-domain}/age-key";
          };
        }
      ];

    _.client.nixos =
      {
        lib,
        host,
        config,
        ...
      }:
      lib.mkMerge [
        (lib.rbn.get-secret' config "kubernetes/k3s/${host.dc-domain}/token")
        {
          services.k3s = {
            role = "agent";
            serverAddr = host.kubernetes.server-addr;
            tokenFile = config.sops.secrets."kubernetes/k3s/${host.dc-domain}/token".path;
          };
        }
      ];

    hm = { pkgs, ... }: {
      home.packages = with pkgs; [
        kubectl
        fluxcd
        cilium-cli
        k9s
      ];
    };
  };
}
