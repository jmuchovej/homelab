{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "homelab.cloudflared";
  config =
    { config, lib, ... }:
    let
      inherit (lib.rebellion.file) get-file;
    in
    {
      sops.secrets."cloudflared" = {
        sopsFile = get-file "secrets/secrets.sops.yaml";
      };

      services.cloudflared = {
        enable = true;
        tunnels = {
          "3326fa87-32b9-4693-9c86-3cbe4e735195" = {
            credentialsFile = config.sops.secrets."cloudflared".path;
            default = "http_status:404";
          };
        };
      };
    };
}
