{
  rbn.programs._.emulators = {
    _.rio = {
      dock.key = "Rio";
      dock.source = "hm";

      hm = { pkgs, ... }: {
        programs.rio = {
          enable = true;
          package = pkgs.rio;
        };
      };
    };

    _.ghostty = {
      dock.key = "Ghostty";
      dock.source = "hm";

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
          settings = {
            font-size = 12;
            font-family = "MonaSpiceKr NF";
            theme = "dark:Flexoki Dark,light:Flexoki Light";
          };
        };
      };
    };

    _.kitty = {
      dock.key = "Kitty";
      dock.source = "hm";

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
      dock.key = "Alacritty";
      dock.source = "hm";

      hm = { pkgs, ... }: {
        programs.alacritty = {
          enable = true;
          package = pkgs.alacritty;
        };
      };
    };

    _.wezterm = {
      dock.key = "WezTerm";
      dock.source = "hm";

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
