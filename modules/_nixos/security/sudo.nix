{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "security.sudo";
  config =
    { lib, ... }:
    let
      inherit (lib) mkForce mkDefault getExe';
    in
    {
      security.sudo = {
        enable = true;

        execWheelOnly = mkForce true;
        wheelNeedsPassword = mkDefault false;

        extraConfig = ''
          Defaults lecture = never # rollback results in sudo lectures after each reboot, it's somewhat useless anyway
          Defaults pwfeedback # password input feedback - makes typed password visible as asterisks
          Defaults env_keep += "EDITOR PATH DISPLAY" # variables that will be passed to the root account
          Defaults timestamp_timeout = 300 # makes sudo ask for password less often
        '';

        extraRules =
          let
            sudo-rules = with pkgs; [
              {
                package = coreutils;
                command = "sync";
              }
              {
                package = hdparm;
                command = "hdparm";
              }
              {
                package = nix;
                command = "nix-collect-garbage";
              }
              {
                package = nix;
                command = "nix-store";
              }
              {
                package = nixos-rebuild-ng;
                command = "nixos-rebuild-ng";
              }
              {
                package = nvme-cli;
                command = "nvme";
              }
              {
                package = systemd;
                command = "poweroff";
              }
              {
                package = systemd;
                command = "reboot";
              }
              {
                package = systemd;
                command = "shutdown";
              }
              {
                package = systemd;
                command = "systemctl";
              }
              {
                package = util-linux;
                command = "dmesg";
              }
            ];

            mk-sudo-rule = rule: {
              command = getExe' rule.package rule.command;
              options = [ "NOPASSWD" ];
            };

            sudo-commands = map mk-sudo-rule sudo-rules;
          in
          [
            {
              groups = [ "wheel" ];
              commands = sudo-commands;
            }
          ];
      };
    };
}
