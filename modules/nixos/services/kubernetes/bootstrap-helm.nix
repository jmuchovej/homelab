{
  pkgs,
  options,
  config,
  lib,
  host,
  namespace,
  ...
}@args:
let
  inherit (lib) mkEnableOption mkOption mkIf types optionals;
  inherit (lib.lists) forEach;
  inherit (builtins) elemAt;
  inherit (lib.strings) splitString;
  inherit (lib.${namespace}) enabled;
  inherit (lib.snowfall.fs) get-file;

  cfg = config.${namespace}.services.kubernetes.helm;

  cilium-values = get-file "kubernetes/apps/kube-system/cilium/app/helm-values.yaml";
  coredns-values = get-file "kubernetes/apps/kube-system/coredns/app/helm-values.yaml";

  k3s-helmfile = ''
  repositories:
    - name: coredns
      url: https://coredns.github.io/helm
    - name: cilium
      url: https://helm.cilium.io
  releases:
    - name: cilium
      namespace: kube-system
      # renovate: repository=https://helm.cilium.io
      chart: cilium/cilium
      version: 1.16.6
      values: ["${cilium-values}"]
      wait: true
    - name: coredns
      namespace: kube-system
      # renovate: repository=https://coredns.github.io/helm
      chart: coredns/coredns
      version: 1.38.1
      values: ["${coredns-values}"]
      wait: true
  '';

  k3s-bootstrap-helm = ''
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    export PATH="$PATH:${pkgs.git}/bin:${pkgs.kubernetes-helm}/bin"
    if ${pkgs.kubectl}/bin/kubectl ${cfg.completed-if} ; then
      exit 0
    fi
    sleep 30
    if ${pkgs.kubectl}/bin/kubectl ${cfg.completed-if} ; then
      exit 0
    fi
    ${pkgs.helmfile}/bin/helmfile \
        --quiet \
        --file ${cfg.file} \
        apply --skip-diff-on-install --suppress-diff
  '';
in
{
  config = mkIf cfg.enable {
    systemd.timers."k3s-bootstrap-helm" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3m";
        OnUnitActiveSec = "3m";
        Unit = "k3s-bootstrap-helm.service";
      };
    };

    environment.etc."k3s/helmfile.yaml" = {
      mode = "0750";
      text = k3s-helmfile;
    };

    systemd.services."k3s-bootstrap-helm" = {
      script = k3s-bootstrap-helm;
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RestartSec = "3m";
      };
    };
  };
}
