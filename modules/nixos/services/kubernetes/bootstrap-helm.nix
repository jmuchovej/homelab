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

  get-k8s = subpath: get-file "kubernetes/apps/" + subpath + "app/helm/values.yaml";

  k3s-helmfile = {
    helmDefaults = {
      cleanupOnFail = true;
      wait = true;
      waitForJobs = true;
    };

    repositories = [
      { name = "cilium"; url = "https://helm.cilium.io"; }
    ];

    releases = [
      {
        name = "cilium";
        namespace = "kube-system";
        # renovate: repository=https://helm.cilium.io
        chart = "cilium/cilium";
        version = "1.17.3";
        values = [ (get-k8s "kube-system/cilium") ];
      }
      {
        name = "coredns";
        namespace = "kube-system";
        # renovate: repository=https://coredns.github.io/helm
        chart = "oci://ghcr.io/coredns/charts/coredns";
        version = "1.39.2";
        values = [ (get-k8s "kube-system/coredns") ];
        needs = ["kube-system/cilium"];
      }
      {
        name = "cert-manager";
        namespace = "cert-manager";
        atomic = true;
        chart = "oci://quay.io/jetstack/charts/cert-manager";
        version = "v1.17.1";
        values = [ (get-k8s "cert-manager/cert-manager") ];
        needs = ["kube-system/coredns"];
      }
      {
        name = "flux-operator";
        namespace = "flux-system";
        atomic = true;
        chart = "oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator";
        version = "0.19.0";
        values = [ (get-k8s "flux-system/flux-operator") ];
        needs = ["cert-manager/cert-manager"];
      }
      {
        name = "flux-instance";
        namespace = "flux-system";
        atomic = true;
        chart = "oci://ghcr.io/controlplaneio-fluxcd/charts/flux-instance";
        version = "0.19.0";
        values = [ (get-k8s "flux-system/flux-instance") ];
        needs = ["flux-system/flux-operator"];
      }
    ];
  };

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
