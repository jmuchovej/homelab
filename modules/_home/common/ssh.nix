{ lib, pkgs, ... }@args:
# Since there _isn't_ a machine I use where the CLI isn't also configured,
#   these are "sane defaults" I expect on any of my machines.
lib.rebellion.mk-module args {
  name = "ssh";
  options = with lib.types; {
    extra-hosts = lib.mkOption {
      type = attrs;
      default = { };
      description = "An 'alias' of `home.programs.ssh.matchBlocks`.";
    };
    authorized-keys = lib.mkOption {
      type = listOf str;
      default = [ ];
      description = "Authorized SSH Keys.";
    };
  };
  config =
    {
      cfg,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkDefault mapAttrs;
      inherit (builtins) concatStringsSep;
      inherit (pkgs.stdenv) isDarwin;

      # Apply default values to extra-hosts if not already set
      applyHostDefaults =
        hostConfig:
        {
          forwardAgent = mkDefault (hostConfig.forwardAgent or isDarwin);
          addKeysToAgent = mkDefault (hostConfig.addKeysToAgent or "no");
        }
        // hostConfig;

      extra-hosts = mapAttrs (_name: applyHostDefaults) cfg.extra-hosts;
    in
    {
      # region ssh #############################################################
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        includes = [ "config.d/*" ];
        matchBlocks = {
          "*" = {
            forwardAgent = isDarwin;
            addKeysToAgent = "no";
            compression = false;
            serverAliveInterval = 0;
            serverAliveCountMax = 3;
            hashKnownHosts = false;
            userKnownHostsFile = "~/.ssh/known_hosts";
            controlMaster = "no";
            controlPath = "~/.ssh/master-%r@%n:%p";
            controlPersist = "no";
            identitiesOnly = isDarwin;
            identityAgent = if isDarwin then "~/.1password/agent.sock" else null;
          };
        }
        // extra-hosts;
      };

      home.file.".ssh/authorized_keys".text = concatStringsSep "\n" cfg.authorized-keys;
      # endregion ##############################################################
    };
}
