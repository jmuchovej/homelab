_: {
  rbn.security._.sudo.nixos =
    { lib, pkgs, ... }:
    let
      inherit (lib) mkForce mkDefault getExe';

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
    in
    {
      security.sudo = {
        enable = true;

        execWheelOnly = mkForce true;
        wheelNeedsPassword = mkDefault false;

        extraConfig = ''
          Defaults lecture = never
          Defaults pwfeedback
          Defaults env_keep += "EDITOR PATH DISPLAY"
          Defaults timestamp_timeout = 300
        '';

        extraRules = [
          {
            groups = [ "wheel" ];
            commands = map mk-sudo-rule sudo-rules;
          }
        ];
      };
    };
}
