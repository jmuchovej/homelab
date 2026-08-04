{
  rbn.programs._.emulators = {
    dock.app = "Rio.app";

    _.rio = {
      hm = { pkgs, ... }: {
        programs.rio = {
          enable = true;
          package = pkgs.rio;
        };
      };
    };

    _.ghostty = {
      dock.app = "Ghostty.app";

      nixos = { pkgs, ... }: {
        environment.systemPackages = [ pkgs.ghostty.terminfo ];
      };

      hm-linux = { pkgs, ... }: {
        programs.ghostty = {
          package = pkgs.ghostty;
          systemd.enable = true;
        };
      };

      hm-macos = { pkgs, ... }: {
        programs.ghostty = {
          package = pkgs.ghostty-bin;
        };
      };

      hm = _: {
        programs.ghostty = {
          enable = true;
          installVimSyntax = true;
          installBatSyntax = true;
        };
      };
    };

    _.kitty = {
      dock.app = "Kitty.app";

      nixos = { pkgs, ... }: {
        environment.systemPackages = [ pkgs.kitty.terminfo ];
      };

      hm = { pkgs, ... }: {
        programs.kitty = {
          enable = true;
          package = pkgs.kitty;
        };
      };
    };

    _.alacritty = {
      dock.app = "Alacritty.app";

      hm = { pkgs, ... }: {
        programs.alacritty = {
          enable = true;
          package = pkgs.alacritty;
        };
      };
    };

    _.wezterm = {
      dock.app = "WezTerm.app";

      hm = { pkgs, ... }: {
        programs.wezterm = {
          enable = true;
          package = pkgs.wezterm;

          extraConfig = builtins.readFile ./wezterm.lua;
        };
      };
    };
  };
}
