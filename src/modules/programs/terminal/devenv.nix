{ inputs, ... }: {
  # Pinned because `devenv` from `nixpkgs` is broken in v2.3.1.
  #   c.f. https://github.com/cachix/devenv/issues/3183
  flake-file.inputs.devenv.url = "github:cachix/devenv/v2.3.1";

  rbn.programs._.terminal._.devenv.hm =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # also provides `secretspec`
      devenv-pkg = inputs.devenv.packages.${pkgs.stdenv.hostPlatform.system}.devenv;
    in
    {
      nix.settings = {
        extra-substituters = [
          "https://devenv.cachix.org"
          "https://nixpkgs-python.cachix.org"
        ];
        extra-trusted-public-keys = [
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
          "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
        ];
      };

      programs.secretspec = {
        enable = true;
        package = devenv-pkg;

        settings = {
          defaults = {
            provider = "1password";
            profile = "development";
            providers = {
              "1password" = "onepassword://";
              sops = "sops://";
              dotenv = "dotenv://";
            };
          };
        };
      };

      programs.devenv = {
        enable = true;
        package = devenv-pkg;
        # settings = {
        # version = 1;
        # shell.prompt_prefix = false;
        # tui.statusline.enabled = true;
        # };
      };

      mcp-servers.settings.servers = {
        devenv = {
          type = "stdio";
          command = lib.getExe config.programs.devenv.package;
          args = [ "mcp" ];
        };
      };
    };
}
