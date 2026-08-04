{
  rbn.programs._.browsers = {
    _.arc = {
      dock.app = "Arc.app";

      macos.homebrew.casks = [ "arc" ];
    };

    _.brave = {
      dock.app = "Brave Browser.app";

      hm-linux = {
        programs.brave.enable = true;
      };

      macos.homebrew.casks = [ "brave-browser" ];
    };

    _.firefox = {
      hm-linux = { pkgs, ... }: {
        programs.firefox.package = pkgs.firefox-devedition;
      };

      hm-macos = {
        # Installed via Brew's `firefox@developer-edition`
        programs.firefox.package = null;
      };

      macos.homebrew.casks = [ "firefox@developer-edition" ];

      hm = { config, user, ... }: {
        programs.firefox = {
          enable = true;

          profiles = {
            "dev-edition-default" = {
              id = 0;
              path = user.name;
            };

            ${user.name} = {
              inherit (import ./_browsers/firefox-profile.nix { inherit config; })
                extensions
                search
                settings
                ;
              id = 1;
            };
          };
        };
      };
    };

    _.google-chrome = {
      hm-linux = {
        programs.google-chrome.enable = true;
      };

      macos.homebrew.casks = [ "google-chrome" ];
    };

    _.vivaldi = {
      hm-linux = {
        programs.vivaldi.enable = true;
      };

      macos.homebrew.casks = [ "vivaldi" ];
    };

    _.zen = {
      hm-linux = { pkgs, ... }: {
        home.packages = [ pkgs.zen-browser ];
      };

      # macos.homebrew.casks = [ "zen-browser" ];
    };
  };
}
