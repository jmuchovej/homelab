{
  config,
  lib,
  pkgs,
  namespace,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    mkForce
    mkDefault
    types
    optionals
    mapAttrs
    ;
  inherit (lib.${namespace}) enabled;
  inherit (builtins) concatStringsSep;
  inherit (pkgs.stdenv) isLinux isDarwin;

  cfg = config.${namespace}.ssh;

  # Apply default values to extra-hosts if not already set
  applyHostDefaults = hostConfig: {
    forwardAgent = mkDefault (hostConfig.forwardAgent or isDarwin);
    addKeysToAgent = mkDefault (hostConfig.addKeysToAgent or "no");
  } // hostConfig;

  extra-hosts = mapAttrs (_name: applyHostDefaults) cfg.extra-hosts;
in
{
  # Since there _isn't_ a machine I use where the CLI isn't also configured,
  #   these are "sane defaults" I expect on any of my machines.
  options.${namespace}.ssh = with types; {
    extra-hosts = mkOption {
      type = attrs;
      default = {};
      description = "An 'alias' of `home.programs.ssh.matchBlocks`.";
    };
    authorized-keys = mkOption {
      type = listOf str;
      default = [];
      description = "Authorized SSH Keys.";
    };
  };

  config = {
    # region ssh #############################################################
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      extraConfig = mkIf isDarwin ''
      '';
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
      } // extra-hosts;
    };

    home.file.".ssh/authorized_keys".text =
      concatStringsSep "\n" cfg.authorized-keys;
    # endregion ##############################################################
  };
}
