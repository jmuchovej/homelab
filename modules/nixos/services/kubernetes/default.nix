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
  inherit (builtins) elemAt;
  inherit (lib.strings) splitString;
  inherit (lib.${namespace}) enabled;
  inherit (lib.snowfall.fs) get-file;

  cfg = config.${namespace}.services.kubernetes;
  datacenter = elemAt (splitString "-" host) 0;
  sopsFile = get-file "secrets/${datacenter}.sops.yaml";
in
{
  options.${namespace}.services.kubernetes = with types; {
    enable = mkEnableOption "kubernetes";
    role = mkOption {
      type = enum [
        "agent"
        "server"
      ];
      default = "server";
      description = "What kind of node is this? (A k3s `server` or `agent`?)";
    };
    is-first = mkEnableOption "set as 'first'.";
    leader  = mkOption {
      type = nullOr str;
      default = null;
      description = "Hostname of the lead server in a multi-node setup.";
    };
    services = {
      coredns = { enable = mkEnableOption "coredns"; };
      kube-proxy = { enable = mkEnableOption "kube-proxy"; };
      flannel = { enable = mkEnableOption "flannel"; };
      flux = { enable = mkEnableOption "flux"; };
      service-lb = { enable = mkEnableOption "service-lb"; };
      traefik    = { enable = mkEnableOption "trefik"; };
      local-io = { enable = mkEnableOption "local IO"; };
      metrics = { enable = mkEnableOption "metrics-server"; };
    };

    helm = {
      enable = mkEnableOption "helm";
      completed-if = mkOption {
        type = types.str;
        description = ''
           kubectl command condition meet when bootstrap is completed
        '';
      };
      file = mkOption {
        type = with types; str;
        description = ''
          Path to bootstrap helmfile
        '';
      };
    };

    minio = {
      enable = mkEnableOption "minio";
      buckets = mkOption {
        type = with types; listOf str;
        default = ["volsync" "postgres"];
        description = ''
          Bucket name.
        '';
      };
      data-dir = mkOption {
        default = [ "/var/lib/minio/data" ];
        type = with types; listOf (either path str);
        description = "The list of data directories or nodes for storing the objects.";
      };
    };
  };

  config = let
    k3sAdmissionPlugins = [
      "DefaultStorageClass"
      "DefaultTolerationSeconds"
      "LimitRanger"
      "MutatingAdmissionWebhook"
      "NamespaceLifecycle"
      "NodeRestriction"
      "PersistentVolumeClaimResize"
      "Priority"
      "ResourceQuota"
      "ServiceAccount"
      "TaintNodesByCondition"
      "ValidatingAdmissionWebhook"
    ];
    k3sDisabledServices = []
      ++ optionals (!cfg.services.flannel.enable) [ "flannel" ]
      ++ optionals (!cfg.services.service-lb.enable) [ "servicelb" ]
      ++ optionals (!cfg.services.coredns.enable) [ "coredns" ]
      ++ optionals (!cfg.services.local-io.enable) [ "local-storage" ]
      ++ optionals (!cfg.services.metrics.enable) [ "metrics-server" ]
      ++ optionals (!cfg.services.traefik.enable) [ "traefik" ]
    ;
    k3sDesiredFlags = [
      "--kubelet-arg=config=/etc/rancher/k3s/kubelet.config"
      "--node-label \"k3s-upgrade=false\""
      "--kube-apiserver-arg anonymous-auth=true"
      "--kube-controller-manager-arg bind-address=0.0.0.0"
      "--kube-scheduler-arg bind-address=0.0.0.0"
      "--etcd-expose-metrics"
      "--secrets-encryption"
      "--write-kubeconfig-mode 0644"
      "--kube-apiserver-arg='enable-admission-plugins=${lib.concatStringsSep "," k3sAdmissionPlugins}'"
      "--flannel-backend=none"
      "--disable-network-policy"
      "--kubelet-arg=register-with-taints=node.cilium.io/agent-not-ready:NoExecute"
    ];
    k3sDisabledFlags = builtins.map (service: "--disable ${service}") k3sDisabledServices;
    k3sExtraFlags = lib.concatLists [k3sDisabledFlags k3sDesiredFlags];
  in mkIf cfg.enable {
    assertions = [{
      assertion = (cfg.is-first && cfg.leader == null) || (!cfg.is-first && cfg.leader != null);
      message = "Cannot both be `first` **and** need a `leader` to connect to!";
    }];

    environment.systemPackages = (with pkgs; [
      cilium-cli
      age fluxcd
      minio-client
      k9s krelay
      helmfile
      kubecolor
      kubectl
      kubectx
      kubelogin
      kubernetes-helm
      kubeseal
    ]);

    environment.etc = {
      "rancher/k3s/kubelet.config" = {
        mode = "0750";
        text = ''
          apiVersion: kubelet.config.k8s.io/v1beta1
          kind: KubeletConfiguration
          maxPods: 250
        '';
      };
      "rancher/k3s/k3s.service.env" = {
        mode = "0750";
        text = ''
          K3S_KUBECONFIG_MODE="644"
        '';
      };
    };

    environment.shellAliases = {
      k = "kubecolor";
      kc = "kubectx";
      kn = "kubens";
      ks = "kubeseal";
    };

    # https://github.com/NixOS/nixpkgs/blob/7d49f7/pkgs/applications/networking/cluster/k3s/docs/USAGE.md
    # https://docs.k3s.io/installation/requirements#inbound-rules-for-k3s-nodes
    networking.firewall = {
      allowedTCPPorts = [
        80 # http
        443 # https
        6443 # k8s API
        8080 # reserved http
        # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
        # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
        10250 # Metrics
      ] ++ [  # Cilium
        4240 # healtchecks
        4244 # hubble server
        4245 # hubble relay
        9962 # prometheus: agent
        9963 # prometheus: operator
        9964 # prometheus: envoy
      ];
      allowedTCPPortRanges = [
        { from = 2379; to = 2380; } # etcd
      ];
      allowedUDPPorts = [
        # TODO tighten this up so only auth'd folks can access
        8472 # VXLAN overlay
      ];
    };

    sops.secrets."k8s/token" = {
      inherit sopsFile;
    };

    services.k3s = enabled // {
      inherit (cfg) role;
      tokenFile = config.sops.secrets."k8s/token".path;
      clusterInit = cfg.is-first;
      serverAddr = mkIf (!cfg.is-first && cfg.leader != null) cfg.leader;
      environmentFile = "/etc/rancher/k3s/k3s.service.env";
      extraFlags = lib.concatStringsSep " " k3sExtraFlags;
    };

    services.prometheus.exporters.node = enabled;

    sops.secrets."minio/credentials" = {
      inherit sopsFile;
      owner = "minio";
      group = "minio";
      mode  = "0770";
    };

    services.minio = mkIf cfg.minio.enable (enabled // {
      region = datacenter;
      dataDir = cfg.minio.data-dir;
      rootCredentialsFile = config.sops.secrets."minio/credentials".path;
    });

    systemd.services.minio-init = mkIf cfg.minio.enable (enabled // {
        path = [ pkgs.minion pkgs.minio-client ];
        requiredBy = [ "multi-user.target" ];
        after = [ "minion.service" ];
        serviceConfig = {
          Type = "simple";
          User = "minio";
          Group = "minio";
          RuntimeDirectory = "minio-config";
        };
        script = ''
          set -e
          sleep 5
          source ${config.services.minio.rootCredentialsFile}
          mc --config-dir "$RUNTIME_DIRECTORY" alias set minio http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
          ${toString (forEach cfg.minio.buckets (b: "mc --config-dir $RUNTIME_DIRECTORY mb --ignore-existing minio/${b};"))}
        '';
    });

    systemd.timers."k3s-bootstrap-helm" = mkIf cfg.helm.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3m";
        OnUnitActiveSec = "3m";
        Unit = "k3s-bootstrap-helm.service";
      };
    };

    systemd.services."k3s-bootstrap-helm" = mkIf cfg.helm.enable {
      script = ''
        export PATH="$PATH:${pkgs.git}/bin:${pkgs.kubernetes-helm}/bin"
        if ${pkgs.kubectl}/bin/kubectl ${cfg.helm.completed-if} ; then
          exit 0
        fi
        sleep 30
        if ${pkgs.kubectl}/bin/kubectl ${cfg.helm.completed-if} ; then
          exit 0
        fi
        ${pkgs.helmfile}/bin/helmfile \
            --quiet \
            --file ${cfg.helm.file} \
            apply --skip-diff-on-install --suppress-diff
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RestartSec = "3m";
      };
    };

    systemd.timers."k3s-bootstrap-flux" = mkIf cfg.services.flux.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3m";
        OnUnitActiveSec = "3m";
        Unit = "k3s-bootstrap-flux.service";
      };
    };

    systemd.services."k3s-bootstrap-flux" = let
      kustomization = builtins.readFile ./flux-kustomization.yaml;
    in mkIf cfg.services.flux.enable {
      script = ''
        export PATH="$PATH:${pkgs.git}/bin"
        if ${pkgs.kubectl}/bin/kubectl get CustomResourceDefinition -A | grep -q "toolkit.fluxcd.io"; then
          exit 0
        fi
        sleep 30
        if ${pkgs.kubectl}/bin/kubectl get CustomResourceDefinition -A | grep -q "toolkit.fluxcd.io"; then
          exit 0
        fi
        mkdir -p /tmp/k3s-bootstrap-flux
        cat > /tmp/k3s-bootstrap-flux <<EOF
          ${kustomization}
        EOF
        ${pkgs.kubectl}/bin/kubctl apply --kustomize /tmp/k3s-bootstrap-flux
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RestartSec = "3m";
      };
    };
  };
}
