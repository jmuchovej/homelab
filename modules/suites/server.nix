{ __findFile, ... }:
{
  rbn.suite._.server = {
    includes = [
      <rbn/suite/common>
      <rbn/suite/development>
      <rbn/system/security/doas>
    ];

    nixos =
      { config, lib, ... }:
      let
        inherit (lib.rebellion.file) get-secret';
      in
      lib.mkMerge [
        (get-secret' config "lab/password")
        {
          documentation = {
            enable = lib.mkForce false;
            info.enable = lib.mkForce false;
            man.enable = lib.mkForce false;
            nixos.enable = lib.mkForce false;
          };

          fonts.fontconfig.enable = lib.mkForce false;

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
            enableEmergencyMode = false;
          };
        }
      ];
  };
}
