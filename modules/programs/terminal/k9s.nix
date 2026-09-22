{ inputs, ... }: {
  rbn.programs._.terminal._.k9s.hm =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (inputs) import-tree;

      # `clusters-root` must stay a string: a path literal would copy each leaf
      # into the store and yield store names instead of "da", with no error.
      clusters-root = "${inputs.self}/kubernetes/clusters";
      cluster-anchor = "/flux/cluster-apps.ks.yaml";
      # unsafeDiscardStringContext must run first: leaves under ${inputs.self}
      # carry store context, which Nix forbids in the `k<ctx>` attribute names below.
      contexts =
        import-tree (i: i.initFilter (lib.hasSuffix cluster-anchor))
          (i: i.map lib.unsafeDiscardStringContext)
          (i: i.map (lib.removeSuffix cluster-anchor))
          (i: i.map baseNameOf)
          (i: i.map (ctx: lib.head (lib.splitString "." ctx)))
          (i: i.leaves clusters-root);

      # One file per context, written by `just k8s kubeconfig`. NOTE: ~/.kube/config
      # must stay first since `kubectl config use-context` writes to the first entry.
      kube-dir = "${config.home.homeDirectory}/.kube";
      configs = [ "config" ] ++ (map (ctx: "config.d/${ctx}.yaml") contexts);
      kubeconfig = lib.concatMapStringsSep ":" (d: "${kube-dir}/${d}") configs;

      # Per-context aliases pin the cluster per command, since current-context
      # is global mutable state shared by every shell.
      mk-context-aliases = ctx: lib.nameValuePair "k${ctx}" "kubecolor --context ${ctx}";
      context-aliases = lib.listToAttrs (map mk-context-aliases contexts);
    in
    {
      home.packages = with pkgs; [
        helmfile
        kubecolor
        kubectl
        kubectx
        kubelogin
        kubernetes-helm
        kubeseal
        fluxcd
        cilium-cli
        minio-client
      ];

      home.sessionVariables.KUBECONFIG = kubeconfig;

      programs.k9s = {
        enable = true;

        settings.k9s = {
          liveViewAutoRefresh = true;
          refreshRate = 1;
          maxConnRetry = 3;
          skipLatestRevCheck = true;
          ui.reactive = true;
          ui.enableMouse = true;
        };
      };

      programs.kubecolor = {
        enable = true;
        enableAlias = true;
      };

      home.shellAliases = {
        k = "kubecolor";
        kc = "kubectx";
        kn = "kubens";
        ks = "kubeseal";
      }
      // context-aliases;
    };
}
