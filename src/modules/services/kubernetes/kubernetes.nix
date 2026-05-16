{ inputs, ... }:
{
  rbn.services._.kubernetes = {
    nixos =
      {
        config,
        pkgs,
        ...
      }:
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

        # 1Password Connect bootstrap secrets — the credentials that let the
        # in-cluster Connect server authenticate to 1Password. ESO can't pull
        # these from 1Password (they ARE the keys to it), so they're seeded
        # out-of-band from sops. Rendered via sops.templates (never in the nix
        # store) and kubectl-applied once k3s is up (no persistent plaintext on
        # disk beyond etcd). Everything else lives in 1Password and flows in via
        # ExternalSecrets once Connect is running.
        sops.secrets."1password/connect.json".sopsFile = "${inputs.self}/secrets/da.sops.yaml";
        sops.secrets."1password/connect-access-token".sopsFile = "${inputs.self}/secrets/da.sops.yaml";

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
            name: onepassword-connect-token
            namespace: external-secrets
          type: Opaque
          stringData:
            token: ${config.sops.placeholder."1password/connect-access-token"}
        '';

        systemd.services.k3s-seed-onepassword = {
          description = "Seed 1Password Connect bootstrap secrets into k3s";
          after = [ "k3s.service" ];
          wants = [ "k3s.service" ];
          wantedBy = [ "multi-user.target" ];
          path = [ pkgs.kubectl ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Environment = "KUBECONFIG=/etc/rancher/k3s/k3s.yaml";
          };
          # apply is idempotent; the Namespace is created first (Flux later
          # adopts it). Secret rotation needs a manual `systemctl restart`.
          script = ''
            until kubectl get --raw /readyz >/dev/null 2>&1; do
              echo "waiting for k3s apiserver..."
              sleep 5
            done
            kubectl apply -f ${config.sops.templates."onepassword-connect.yaml".path}
          '';
        };
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.k9s ];
      };
  };
}
