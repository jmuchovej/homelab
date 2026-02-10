{
  pkgs,
  config,
  lib,
  host,
  ...
}:
let
  inherit (lib)
    mkIf
    ;
  inherit (lib.lists) forEach;
  inherit (builtins) elemAt;
  inherit (lib.strings) splitString;
  inherit (lib.rebellion) enabled;
  inherit (lib.rebellion.file) get-file;

  k8s = config.rebellion.services.kubernetes;
  cfg = config.rebellion.services.kubernetes.minio;
  datacenter = elemAt (splitString "-" host) 0;
  sopsFile = get-file "secrets/${datacenter}.sops.yaml";
in
{
  config = mkIf (k8s.enable && cfg.enable) {
    sops.secrets."minio/credentials" = {
      inherit sopsFile;
      owner = "minio";
      group = "minio";
      mode = "0770";
    };

    services.minio = enabled // {
      region = datacenter;
      dataDir = cfg.data-dir;
      rootCredentialsFile = config.sops.secrets."minio/credentials".path;
    };

    systemd.services.minio-init = enabled // {
      path = [
        pkgs.minion
        pkgs.minio-client
      ];
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
        ${toString (
          forEach cfg.buckets (b: "mc --config-dir $RUNTIME_DIRECTORY mb --ignore-existing minio/${b};")
        )}
      '';
    };
  };
}
