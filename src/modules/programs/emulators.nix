{
  rbn.programs._.emulators = {
    _.rio = {
      hm-linux = { pkgs, ... }: {
        programs.rio = {
          enable = true;
          package = pkgs.rio;
        };
      };

      macos.homebrew.casks = [ "rio" ];
    };

    _.ghostty = {
      dock.app = "Ghostty.app";

      nixos = { pkgs, ... }: {
        environment.systemPackages = [ pkgs.ghostty.terminfo ];
      };

      hm-linux = { pkgs, ... }: {
        programs.ghostty = {
          enable = true;
          package = pkgs.ghostty;
        };
      };

      macos.homebrew.casks = [ "ghostty" ];
    };

    _.kitty = {
      hm-linux = { pkgs, ... }: {
        programs.kitty = {
          enable = true;
          package = pkgs.kitty;
        };
      };
    };

    _.alacritty = {
      hm-linux = { pkgs, ... }: {
        programs.alacritty = {
          enable = true;
          package = pkgs.alacritty;
        };
      };

      macos.homebrew.casks = [ "alacritty" ];
    };

    _.wezterm = {
      dock.app = "WezTerm.app";

      hm-linux = { pkgs, ... }: {
        programs.wezterm = {
          enable = true;
          package = pkgs.wezterm;
          enableBashIntegration = true;
          enableZshIntegration = true;

          extraConfig = builtins.readFile ./wezterm.lua;
        };
      };

      macos.homebrew.casks = [ "wezterm" ];
    };
  };
}
