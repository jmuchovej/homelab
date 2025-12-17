{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "git";
  options =
    let
      inherit (lib) types mkOption;
    in
    {
      email = mkOption {
        type = types.nullOr types.str;
        default = "jmuchovej@users.noreply.github.com";
        description = "The email to use with git.";
      };
      allowed-signers = mkOption {
        type = types.str;
        default = "";
        description = "The public key used for signing commits";
      };
    };
  config =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib) optionals;
      inherit (pkgs.stdenv) isDarwin;

      cfg = config.rebellion.git;
    in
    {
      home.file.".ssh/allowed_signers".text = "* ${cfg.allowed-signers}";

      xdg.configFile."git/ignore" = {
        enable = true;
        text = ''
          _research/
          .scratch/
          .arxiv/
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

        settings = {
          user.name = "John Muchovej";
          user.email = cfg.email;

          gpg.format = "ssh";
          # gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
          # TODO migrate to platform-independent and don't do for remote hosts
          gpg.ssh.program = optionals isDarwin "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
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

          # delta = {
          #   enable = true;
          #   options = {
          #     navigate = true;
          #     side-by-side = true;
          #     light = false;
          #     syntax-theme = "catppuccin";
          #   };
          # };

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
