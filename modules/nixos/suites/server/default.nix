{
  options,
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption mkForce;
  inherit (lib.${namespace}) enabled;
  inherit (lib.snowfall.fs) get-file;

  cfg = config.${namespace}.suites.server;
in
{
  options.${namespace}.suites.server = {
    enable = mkEnableOption "`server` suite";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      suites = {
        common      = enabled;
        development = enabled;
      };
      services = {
        tailscale = enabled;
      };
    };

    security = {
      doas = enabled;
    };

    # Notice this also disables --help for some commands such es nixos-rebuild
    documentation = {
      enable        = mkForce false;
      info.enable   = mkForce false;
      man.enable    = mkForce false;
      nixos.enable  = mkForce false;
    };

    fonts.fontconfig.enable = mkForce false;

    environment.systemPackages = [ ];

    users.mutableUsers = false;

    sops.secrets."lab/password".sopsFile = (get-file "secrets/secrets.sops.yaml");
    sops.secrets."lab/password".neededForUsers = true;

    users.users.lab = {
      hashedPasswordFile          = config.sops.secrets."lab/password".path;
      isNormalUser                = true;
      extraGroups                 = [ "wheel" "video" "games" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3FPLe1ZXSk7KBgSkJud2hlvUAGF5m57g2Pqpccy5SO lab@home.jm0.io"
      ];
    };

    systemd = {
      network.wait-online.enable = false;

      # Given that our systems are headless, emergency mode is useless.
      # We prefer the system to attempt to continue booting so
      # that we can hopefully still access it remotely.
      enableEmergencyMode = false;
    };
  };
}
