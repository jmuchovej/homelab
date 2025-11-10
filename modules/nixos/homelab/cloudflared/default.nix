{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.homelab.cloudflared;
in {
  options.${namespace}.homelab.cloudflared = {
    enable = mkEnableOption "cloudflared";
  };

  config = mkIf cfg.enable {
    sops.secrets."cloudflared" = {
      sopsFile = lib.snowfall.fs.get-file "secrets/secrets.sops.yaml";
      owner = "cloudflared";
    };

    services = {
      cloudflared = {
        enable = true;
        tunnels = {
          "3326fa87-32b9-4693-9c86-3cbe4e735195" = {
            credentialsFile = config.sops.secrets."cloudflared".path;
            default = "http_status:404";
          };
        };
      };
    };
  };
}
