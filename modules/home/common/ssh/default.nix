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
    ;
  inherit (lib.${namespace}) enabled;
  inherit (builtins) concatStringsSep;
  inherit (pkgs.stdenv) isLinux isDarwin;

  cfg = config.${namespace}.ssh;
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
      forwardAgent = isDarwin;
      addKeysToAgent = "no";
      extraConfig = mkIf isDarwin ''
        IdentitiesOnly yes
        IdentityAgent ~/.1password/agent.sock
      '';
      matchBlocks = cfg.extra-hosts;
    };

    home.file.".ssh/authorized_keys".text =
      concatStringsSep "\n" cfg.authorized-keys;
    # endregion ##############################################################
  };
}

