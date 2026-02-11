{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.kubernetes";
  description = "kubernetes";
  imports = [
    ./kubernetes/bootstrap-apps.nix
    ./kubernetes/bootstrap-minio.nix
  ];
  options =
    { lib, ... }:
    let
      inherit (lib) mkOption types;
      inherit (lib.rebellion) mkopt-enable;
    in
    {
      role = mkOption {
        type = types.enum [
          "agent"
          "server"
        ];
        default = "server";
        description = "What kind of node is this? (A k3s `server` or `agent`?)";
      };
      is-first = mkopt-enable "set as 'first'.";
      leader = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Hostname of the lead server in a multi-node setup.";
      };
      cidr = {
        cluster = mkOption {
          type = types.str;
          description = "CIDR for Pods.";
        };
        service = mkOption {
          type = types.str;
          description = "CIDR for Servicees.";
        };
      };
      services = {
        coredns = {
          enable = mkopt-enable "coredns";
        };
        kube-proxy = {
          enable = mkopt-enable "kube-proxy";
        };
        flannel = {
          enable = mkopt-enable "flannel";
        };
        flux = {
          enable = mkopt-enable "flux";
        };
        service-lb = {
          enable = mkopt-enable "service-lb";
        };
        traefik = {
          enable = mkopt-enable "trefik";
        };
        local-io = {
          enable = mkopt-enable "local IO";
        };
        metrics = {
          enable = mkopt-enable "metrics-server";
        };
      };

      helm = {
        enable = mkopt-enable "helm";
        completed-if = mkOption {
          type = types.str;
          description = ''
            kubectl command condition meet when bootstrap is completed
          '';
        };
        file = mkOption {
          type = types.str;
          description = ''
            Path to bootstrap helmfile
          '';
        };
      };

      minio = {
        enable = mkopt-enable "minio";
        buckets = mkOption {
          type = types.listOf types.str;
          default = [
            "volsync"
            "postgres"
          ];
          description = ''
            Bucket name.
          '';
        };
        data-dir = mkOption {
          default = [ "/var/lib/minio/data" ];
          type = types.listOf (types.either types.path types.str);
          description = "The list of data directories or nodes for storing the objects.";
        };
      };
    };
  config =
    {
      cfg,
      lib,
      pkgs,
      config,
      host,
      ...
    }:
    let
      inherit (builtins) elemAt readFile;
      inherit (lib) mkIf optionals;
      inherit (lib.strings) splitString;
      inherit (lib.rebellion) enabled;
      inherit (lib.rebellion.file) get-file;

      datacenter = elemAt (splitString "-" host) 0;
      sopsFile = get-file "secrets/${datacenter}.sops.yaml";

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
      k3sDisabledServices =
        optionals (!cfg.services.flannel.enable) [ "flannel" ]
        ++ optionals (!cfg.services.service-lb.enable) [ "servicelb" ]
        ++ optionals (!cfg.services.coredns.enable) [ "coredns" ]
        ++ optionals (!cfg.services.local-io.enable) [ "local-storage" ]
        ++ optionals (!cfg.services.metrics.enable) [ "metrics-server" ]
        ++ optionals (!cfg.services.traefik.enable) [ "traefik" ];
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
        "--cluster-cidr=${cfg.cidr.cluster}"
        "--service-cidr=${cfg.cidr.service}"
      ]
      ++ (optionals (!cfg.services.flannel.enable) [
        "--flannel-backend=none"
        "--disable-network-policy"
      ])
      ++ (optionals (!cfg.services.kube-proxy.enable) [
        "--disable-kube-proxy"
        "--disable-cloud-controller"
      ]);
      # NOTE this creates a chicken-and-egg problem with deploying Cilium. Lol.
      # "--kubelet-arg=register-with-taints=node.cilium.io/agent-not-ready:NoExecute"
      k3sDisabledFlags = builtins.map (service: "--disable ${service}") k3sDisabledServices;
      k3sExtraFlags = lib.concatLists [
        k3sDisabledFlags
        k3sDesiredFlags
      ];
    in
    {
      assertions = [
        {
          assertion = (cfg.is-first && cfg.leader == null) || (!cfg.is-first && cfg.leader != null);
          message = "Cannot both be `first` **and** need a `leader` to connect to!";
        }
      ];

      users.groups.k3s = { };

      systemd.tmpfiles.rules = [
        "f /etc/rancher/k3s/k3s.yaml 0640 root k3s"
      ];

      environment.extraInit = ''
        if groups | grep -q k3s; then
          export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        fi
      '';

      environment.systemPackages = with pkgs; [
        jq
        cilium-cli
        age
        fluxcd
        sops
        minio-client
        k9s
        krelay
        helmfile
        kubecolor
        kubectl
        kubectx
        kubelogin
        (wrapHelm kubernetes-helm {
          plugins = with pkgs.kubernetes-helmPlugins; [
            helm-diff
            helm-secrets
            helm-git
            helm-s3
          ];
        })
        kubeseal

        (writeShellScriptBin "nuke-k3s" (readFile ./nuke-k3s))
      ];

      environment.etc."rancher/k3s/kubelet.config" = {
        mode = "0750";
        text = ''
          apiVersion: kubelet.config.k8s.io/v1beta1
          kind: KubeletConfiguration
          maxPods: 250
          clusterDNS:
            - 10.70.0.53
          clusterDomain: cluster.local
        '';
      };
      environment.etc."rancher/k3s/k3s.service.env" = {
        mode = "0750";
        text = ''
          K3S_KUBECONFIG_MODE="644"
        '';
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
        ]
        ++ [
          # Cilium
          4240 # healtchecks
          4244 # hubble server
          4245 # hubble relay
          9962 # prometheus: agent
          9963 # prometheus: operator
          9964 # prometheus: envoy
        ];
        allowedTCPPortRanges = [
          {
            from = 2379;
            to = 2380;
          } # etcd
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
    };
}
