{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
let
  inherit (lib)
    types
    mkIf
    mkEnableOption
    mkOption
    ;

  cfg = config.${namespace}.programs.tools.git;

in
{
  options.${namespace}.programs.tools.git = with types; {
    enable = mkEnableOption "git";
    email = mkOption {
      type = nullOr str;
      default = "jmuchovej@users.noreply.github.com";
      description = "The email to use with git.";
    };
    allowedSigners = mkOption {
      type = str;
      default = "";
      description = "The public key used for signing commits";
    };
  };

  config = mkIf cfg.enable {
    home.file.".ssh/allowed_signers".text = "* ${cfg.allowedSigners}";

    xdg.configFile."git/ignore" = {
      enable = true;
      text = ''
        _research
      '';
    };

    home.packages = with pkgs; [
      delta
      difftastic
    ];

    programs.git-credential-oauth = {
      enable = true;
    };
    programs.git = {
      enable = true;
      userName = "John Muchovej";
      userEmail = cfg.email;

      extraConfig = {
        gpg.format = "ssh";
        # gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
        # TODO migrate to platform-independent and don't do for remote hosts
        gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
        commit.gpgsign = true;
        tag.gpgsign = true;
        # user.signingkey = "~/.ssh/1p-github.com.pub";
        user.signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPzVs6NgTgGHRUb2AOW3iLsuCpRXLVMleeLeQ3FYF8Kb";

        color = {
          ui = true;
        };

        # difftastic = {
        #   enable      = true;
        #   background  = "dark";
        #   color       = "always";
        #   display     = "side-by-side";
        # };

        delta = {
          enable = true;
          options = {
            navigate = true;
            side-by-side = true;
            light = false;
            syntax-theme = "catppuccin";
          };
        };

        pull = {
          ff = "only";
        };

        push = {
          default = "current";
          autoSetupRemote = true;
        };

        init = {
          defaultBranch = "main";
        };

        filter.lfs = {
          required = true;
          clean = "git-lfs clean -- %f";
          smudge = "git-lfs smudge -- %f";
          process = "git-lfs filter-process -- %f";
        };
      };
    };
  };
}
