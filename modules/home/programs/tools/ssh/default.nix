{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption mkOption;
  inherit (lib.types) attrsOf submodule str literalExample;

  cfg = config.${namespace}.programs.tools.ssh;
in {
  options.${namespace}.programs.tools.ssh = {
    enable = mkEnableOption "ssh";

    extraHosts = mkOption {
      type = attrsOf (submodule {
        options = {
          hostname = mkOption {
            type = str;
            description = "The hostname or IP address of the SSH host.";
          };
          identityFile = mkOption {
            type = str;
            description = "The path to the identity file for the SSH host.";
          };
        };
      });
      default = {};
      description = "A set of extra SSH hosts.";
      example = literalExample ''
        {
          "gitlab-personal" = {
            hostname = "gitlab.com";
            identityFile = "~/.ssh/id_ed25519_personal";
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    # programs.keychain = {
    #   enable = true;
    #   keys = ["1p-homelab" "1p-github.com" "1p-gitlab.com" "1p-gitea.com" "1p-bitbucket.com"];
    #   agents = ["gpg" "ssh"];
    # };

    programs.ssh = {
      enable = true;
      forwardAgent = true;
      addKeysToAgent = "yes";
      extraConfig = ''
        IdentitiesOnly  yes
        IdentityAgent   ~/.1password/agent.sock
      '';
      # matchBlocks = cfg.extraHosts;
      matchBlocks = {
        git = {
          host          = "git*";
          identityFile  = "~/.ssh/1p-%h.pub";
        };
      };
    };
  };
}
