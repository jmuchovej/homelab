{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.k9s";
  config =
    {
      pkgs,
      ...
    }:
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

      programs.k9s = {
        enable = true;
        package = pkgs.k9s;

        settings.k9s = {
          liveViewAutoRefresh = true;
          refreshRate = 1;
          maxConnRetry = 3;
          ui = {
            enableMouse = true;
          };
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
      };
    };
}
