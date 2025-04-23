{
  pkgs,
  options,
  config,
  lib,
  host,
  namespace,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption mkIf types optionals;
  inherit (lib.lists) forEach;
  inherit (builtins) elemAt readFile;
  inherit (lib.strings) splitString;
  inherit (lib.${namespace}) enabled;
  inherit (lib.snowfall.fs) get-file;

  cfg = config.${namespace}.services.kubernetes.services.flux;

  yaml-format = (pkgs.formats.yaml { });

  k3s-flux = {
    apiVersion = "kustomize.config.k8s.io/v1beta1";
    kind =  "Kustomization";
    resources = [
      "github.com/fluxcd/flux2/manifests/install"
    ];
    patches = [
      # Remove the default network policies
      {
        patch = ''
          $patch: delete
          apiVersion: networking.k8s.io/v1
          kind: NetworkPolicy
          metadata:
            name: not-used
        '';
        target = {
          group = "networking.k8s.io";
          kind = "NetworkPolicy";
        };
      }
    ];
  };
  kubectl-bin = "${pkgs.kubectl}/bin/kubectl";

  k3s-bootstrap-flux = ''
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    export PATH="$PATH:${pkgs.git}/bin"
    if ${pkgs.kubectl}/bin/kubectl get CustomResourceDefinition -A | grep -q "toolkit.fluxcd.io"; then
      exit 0
    fi
    sleep 30
    if ${pkgs.kubectl}/bin/kubectl get CustomResourceDefinition -A | grep -q "toolkit.fluxcd.io"; then
      exit 0
    fi
    mkdir -p /tmp/k3s-bootstrap-flux
    cat > /tmp/k3s-bootstrap-flux/kustomization.yaml <<EOF
      apiVersion: kustomize.config.k8s.io/v1beta1
      kind: Kustomization
      resources:
        - github.com/fluxcd/flux2/manifests/install
      patches:
        # Remove the default network policies
        - patch: |-
            \$patch: delete
            apiVersion: networking.k8s.io/v1
            kind: NetworkPolicy
            metadata:
              name: not-used
          target:
            group: networking.k8s.io
            kind: NetworkPolicy
    EOF
    ${pkgs.kubectl}/bin/kubctl apply --kustomize /tmp/k3s-bootstrap-flux
  '';
in
{
  config = mkIf cfg.enable {
    systemd.timers."k3s-bootstrap-flux" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3m";
        OnUnitActiveSec = "3m";
        Unit = "k3s-bootstrap-flux.service";
      };
    };

    systemd.services."k3s-bootstrap-flux" = {
      script = ''
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        export PATH="$PATH:${pkgs.git}/bin"
        if ${kubectl-bin} get CustomResourceDefinition -A | grep -q "toolkit.fluxcd.io"; then
          exit 0
        fi
        sleep 30
        if ${kubectl-bin} get CustomResourceDefinition -A | grep -q "toolkit.fluxcd.io"; then
          exit 0
        fi
        mkdir -p /tmp/k3s-bootstrap-flux
        cat > /tmp/k3s-bootstrap-flux/kustomization.yaml <<EOF
          apiVersion: kustomize.config.k8s.io/v1beta1
          kind: Kustomization
          resources:
            - github.com/fluxcd/flux2/manifests/install
          patches:
            # Remove the default network policies
            - patch: |-
                \$patch: delete
                apiVersion: networking.k8s.io/v1
                kind: NetworkPolicy
                metadata:
                  name: not-used
              target:
                group: networking.k8s.io
                kind: NetworkPolicy
        EOF
        ${kubectl-bin} apply --kustomize /tmp/k3s-bootstrap-flux
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RestartSec = "3m";
      };
    };
  };
}
