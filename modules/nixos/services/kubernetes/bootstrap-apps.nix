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
  inherit (builtins) elemAt concatStringsSep;
  inherit (lib.strings) splitString;
  inherit (lib.${namespace}) enabled;
  inherit (lib.snowfall.fs) get-directories get-file;

  cfg = config.${namespace}.services.kubernetes.helm;
  yaml-format = (pkgs.formats.yaml { });

  get-k8s = subpath: get-file ("kubernetes/apps/" + subpath + "/app/helm/values.yaml");
  k3s-apply = fn: array: (concatStringsSep "\n" (map (e: "${fn} \"${e}\"") array));

  # NOTE: for some reason, this _has to be_ an absolute path? ergo `get-file` prefixes the Nix path
  k3s-namespaces = get-directories (get-file "kubernetes/apps");

  k3s-resources = [
    (get-file "kubernetes/bootstrap.sops.yaml")
  ];

  k3s-crds = [
    # renovate: datasource=github-releases depName=prometheus-operator/prometheus-operator
    "https://github.com/prometheus-operator/prometheus-operator/releases/download/v0.82.0/stripped-down-crds.yaml"
    # renovate: datasource=github-releases depName=kubernetes-sigs/external-dns
    "https://raw.githubusercontent.com/kubernetes-sigs/external-dns/refs/tags/v0.16.1/docs/sources/crd/crd-manifest.yaml"
  ];

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
        name = "external-secrets";
        namespace = "external-secrets";
        chart = "oci://ghcr.io/external-secrets/charts/external-secrets";
        version = "0.16.2";
        values = [ (get-k8s "external-secrets/external-secrets") ];
        hooks = [
          { # Apply cluster secret store
            events = ["postsync"];
            command = "kubectl";
            args = [
              "apply"
              "--namespace=external-secrets"
              "--server-side"
              "--field-manager=kustomize-controller"
              "--filename"
              "../kubernetes/apps/external-secrets/external-secrets/app/clustersecretstore.yaml"
              "--wait=true"
            ];
            showlogs = true;
          }
        ];
        needs = ["cert-manager/cert-manager"];
      }
      {
        name = "flux-operator";
        namespace = "flux-system";
        atomic = true;
        chart = "oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator";
        version = "0.19.0";
        values = [ (get-k8s "flux-system/flux-operator") ];
        needs = ["external-secrets/external-secrets"];
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
in {
  config = mkIf cfg.enable {
    systemd.timers."k3s-bootstrap-apps" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3m";
        OnUnitActiveSec = "3m";
        Unit = "k3s-bootstrap-apps.service";
      };
    };

    environment.etc."k3s/helmfile.yaml" = {
      mode = "0750";
      source = yaml-format.generate "helmfile.yaml" k3s-helmfile;
    };

    systemd.services."k3s-bootstrap-apps" = {
      path = with pkgs; [
        git gawk coreutils
        kubectl helmfile kubernetes-helm
        sops age ssh-to-age
      ];
      environment = {
        KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
        # TODO this is a hacky work-around that i don't really like...
        SOPS_AGE_KEY_FILE = "/var/lib/sops-nix/key.txt";
      };
      script = ''

      function apply_namespace() {
        local NAMESPACE="''${1}"
        local namespace="$(basename ''${NAMESPACE})"

        if kubectl get namespace "''${namespace}" &>/dev/null; then
          echo "NAMESPACE already exists! (''${namespace})"
          return
        fi

        if kubectl create namespace "''${namespace}" --dry-run=client --output=yaml \
            | kubectl apply --server-side --filename - &>/dev/null; then
          echo "Created NAMESPACE! (''${namespace})"
        else
          echo "Failed to create NAMESPACE! (''${namespace})"
        fi
      }

      function apply_resource() {
        local RESOURCE="''${1}"
        local resource="$(basename ''${RESOURCE})"

        if [ ! -f "''${RESOURCE}" ]; then
          echo "File does not exist! (''${resource})"
          return
        fi
        if sops exec-file "''${RESOURCE}" "kubectl diff -f {}" &>/dev/null; then
          echo "RESOURCE is up-to-date! (''${resource})"
          return
        fi

        if sops exec-file "''${RESOURCE}" "kubectl apply --server-side -f {}" &>/dev/null; then
          echo "Successfully applied RESOURCE! (''${resource})"
        else
          echo "Failed to apply RESOURCE... (''${resource})"
        fi
      }

      function apply_crd() {
        local CRD="''${1}"
        local crd="$(echo "''${CRD}" | awk -F/ '{print $4"/"$5}')"

        if kubectl diff --filename "''${CRD}" &>/dev/null; then
          echo "CRD is up-to-date! (''${crd})"
          return
        fi
        if kubectl apply --server-side --filename "''${CRD}" &>/dev/null; then
          echo "Applied CRD! (''${crd})"
        else
          echo "Failed to apply CRD! (''${crd})"
        fi
      }

      # Apply NAMESPACES
      ${k3s-apply "apply_namespace" k3s-namespaces}

      # Apply SECRETS
      ${k3s-apply "apply_resource" k3s-resources}

      # Apply CRDs
      ${k3s-apply "apply_crd" k3s-crds}

      # Apply Helm Releases
      helmfile apply \
        --file /etc/${config.environment.etc."k3s/helmfile.yaml".target} \
        --hide-notes --skip-diff-on-install --suppress-diff --suppress-secrets
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RestartSec = "3m";
      };
    };
  };
}
