_: {
  rbn.services._.kubernetes = {
    nixos =
      { pkgs, ... }:
      {
        # Cluster admin CLIs (k9s is in the home-manager aspect below).
        environment.systemPackages = [
          pkgs.kubectl
          pkgs.cilium-cli
          pkgs.fluxcd
        ];

        services.k3s = {
          enable = true;
          role = "server";
          gracefulNodeShutdown.enable = true;

          # Replace k3s' batteries with the Cilium/Flux/Envoy stack. flannel,
          # kube-proxy and network-policy toggle via dedicated flags below; the
          # rest are addon names disabled here. coredns is kept.
          disable = [
            "traefik"
            "servicelb"
            "local-storage"
            "metrics-server"
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

          # Bootstrap manifests, symlinked into the k3s auto-deploy dir (no Nix
          # build-time fetch/convert — k3s' helm-controller pulls the charts at
          # runtime, which also keeps cross-arch deploys from the darwin
          # workstation working). Authored as plain YAML for editability.
          #
          #   cilium        — the CNI (HelmChart, bootstrap), installed before
          #                   the node can go Ready.
          #   flux-operator — installs Flux + reconciles the FluxInstance.
          #   flux-instance — GitOps entrypoint (retries until the operator CRD
          #                   exists).
          manifests = {
            cilium.source = ./manifests/cilium.yaml;
            flux-operator.source = ./manifests/flux-operator.yaml;
            flux-instance.source = ./manifests/flux-instance.yaml;
          };
        };

        # k3s apiserver (6443), kubelet (10250), BGP (179), Cilium health (4240).
        networking.firewall.allowedTCPPorts = [
          6443
          10250
          179
          4240
        ];
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.k9s ];
      };
  };
}
