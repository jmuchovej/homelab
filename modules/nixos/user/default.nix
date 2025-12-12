{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) types mkOption;

  cfg = config.rebellion.user;
in
{
  options.rebellion.user = with types; {
    name = mkOption {
      type = str;
      default = "lab";
      description = "The user account.";
    };
    email = mkOption {
      type = str;
      default = "jmuchovej@pm.me";
      description = "The user's email.";
    };
    fullName = mkOption {
      type = str;
      default = "Homelab";
      description = "The user's full name";
    };
    extra = {
      groups = mkOption {
        type = listOf str;
        default = [ ];
        description = "Extra groups to assign.";
      };
      options = mkOption {
        type = attrs;
        default = { };
        description = "Extra options to pass to <option>users.users.<name></option>.";
      };
    };
  };

  config = {
    environment.pathsToLink = [ "/share/zsh" ];

    programs.zsh = {
      enable = true;
      autosuggestions.enable = true;
      histFile = "$XDG_CACHE_HOME/zsh.history";
    };

    users.users.${cfg.name} = {
      inherit (cfg) name;

      shell = pkgs.zsh;

      extraGroups = [
        "wheel"
        "systemd-journal"
        "audio"
        "video"
        "nix"
      ] ++ cfg.extra.groups;

      group = "users";
      home = "/home/${cfg.name}";
      isNormalUser = true;
    } // cfg.extra.options;
  };
}
