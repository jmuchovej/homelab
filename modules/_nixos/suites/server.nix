{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "suites.server";
  description = "`server` suite";
  config =
    { config, lib, ... }:
    let
      inherit (lib.rebellion) enabled;
      inherit (lib.rebellion.file) get-secret';
    in
    lib.mkMerge [
      (get-secret' config "lab/password")
      {
        rebellion.suites.common = enabled;
        rebellion.suites.development = enabled;
        rebellion.services.tailscale = enabled;
        rebellion.security.doas = enabled;

        # Notice this also disables --help for some commands such es nixos-rebuild
        documentation = {
          enable = lib.mkForce false;
          info.enable = lib.mkForce false;
          man.enable = lib.mkForce false;
          nixos.enable = lib.mkForce false;
        };

        fonts.fontconfig.enable = lib.mkForce false;

        environment.systemPackages = [ ];

        users.mutableUsers = false;

        sops.secrets."lab/password".neededForUsers = true;

        users.users.lab = {
          hashedPasswordFile = config.sops.secrets."lab/password".path;
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "video"
            "games"
          ];
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
      }
    ];
}
