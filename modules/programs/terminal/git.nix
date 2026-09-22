{
  rbn.programs._.terminal._.git.hm = { user, lib, ... }: {
    home.shellAliases = {
      lg = "lazygit";
    };

    programs.git =
      let
        ssh-to-https =
          _: forge:
          lib.nameValuePair "git@${forge.host}:" {
            insteadOf = [
              "${forge.short}:"
              "https://${forge.host}"
            ];
          };
      in
      {
        enable = true;
        signing.format = null;
        settings = {
          user = {
            name = user.fullname;
            inherit (user) email;
          };

          ## `forge:owner/repo` shorthand, plus https -> ssh. jj honors these
          ## too, so `jj clone github:owner/repo` resolves through git config.
          url = lib.mapAttrs' ssh-to-https user.forges;

          color.ui = true;
          init.defaultBranch = "main";
          pull.ff = "only";
          push = {
            default = "current";
            autoSetupRemote = true;
          };
          lfs.enable = true;
        };

        ignores = lib.splitString "\n" (builtins.readFile ./gitignore);
      };

    programs.lazygit = {
      enable = true;
      settings = {
        gui = {
          authorColors = {
            "${user.fullname}" = "#c6a0f6";
            "dependabot[bot]" = "#eed49f";
          };
          branchColors = {
            main = "#ed8796";
            master = "#ed8796";
            dev = "#8bd5ca";
          };
          nerdFontsVersion = "3";
        };
        git.overrideGpg = true;
      };
    };
  };
}
