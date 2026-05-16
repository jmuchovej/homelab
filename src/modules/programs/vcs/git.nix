_: {
  rbn.programs._.vcs._.git.homeManager =
    { lib, pkgs, ... }:
    let
      inherit (lib) optionals;
      inherit (pkgs.stdenv) isDarwin;
    in
    {
      home.file.".ssh/allowed_signers".text =
        "* ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPzVs6NgTgGHRUb2AOW3iLsuCpRXLVMleeLeQ3FYF8Kb";

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

      programs.git-credential-oauth.enable = true;

      programs.git = {
        enable = true;

        signing.format = null;

        settings = {
          user.name = "John Muchovej";
          user.email = "jmuchovej@users.noreply.github.com";

          gpg.format = "ssh";
          gpg.ssh.program = optionals isDarwin "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
          commit.gpgsign = true;
          tag.gpgsign = true;
          user.signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPzVs6NgTgGHRUb2AOW3iLsuCpRXLVMleeLeQ3FYF8Kb";

          color.ui = true;

          pull.ff = "only";

          push = {
            default = "current";
            autoSetupRemote = true;
          };

          init.defaultBranch = "main";

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
