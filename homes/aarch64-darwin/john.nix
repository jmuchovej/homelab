{
  lib,
  config,
  ...
}:
let
  inherit (lib) mkDefault;
  inherit (lib.rebellion) enabled disabled;
in
{
  rebellion = {
    user = {
      name = "john";
      real-name = "John Muchovej";
    };

    editor = {
      neovim = mkDefault enabled;
      vscode = mkDefault enabled;
      zed = mkDefault enabled // {
        default = true;
      };
    };
    desktop = enabled // {
      wezterm = mkDefault enabled;
      brave = enabled;
      # firefox = enabled;
      # ghostty = mkDefault enabled;
      # arc     = enabled;
      appflowy = enabled;
      # anytype = enabled;
      logseq = enabled;
      obsidian = enabled;
    };

    shell = {
      bash = mkDefault enabled;
      nushell = mkDefault enabled;
      zsh = mkDefault enabled;
    };

    development = enabled // {
      app = enabled;
      web = enabled;
      go = enabled;
      julia = enabled;
      nix = enabled;
      python = enabled;
      R = disabled;
      rust = disabled;
      typst = enabled;
    };

    ssh = {
      extra-hosts = {
        git = {
          host = "git*";
          identitiesOnly = true;
          identityFile = "~/.ssh/1p-%h.pub";
        };
      };
      authorized-keys = [ ];
    };

    programs.tools.onepassword-cli.ssh-socket = enabled;
    programs.terminal.tools = {
      mcp = enabled // {
        filesystem.directories = [
          "${config.home.homeDirectory}/Syncthing"
        ];
      };
      claude = enabled // {
        code = enabled;
        desktop = enabled;
      };
    };

    dock.entries = [
      {
        name = "System Settings.app";
        source = "system";
        group = "system";
        order = 110;
      }
      {
        path = "/System/Applications/Utilities/Activity Monitor.app";
        group = "system";
        order = 120;
      }
      {
        name = "Messages.app";
        source = "system";
        group = "communication";
        order = 210;
      }
      {
        name = "Beeper Desktop.app";
        source = "applications";
        group = "communication";
        order = 220;
      }
      {
        name = "Things3.app";
        source = "applications";
        group = "communication";
        order = 240;
      }
      {
        name = "Safari.app";
        source = "applications";
        group = "browsers";
        order = 330;
      }
      {
        name = "Notion Calendar.app";
        source = "applications";
        group = "pkm";
        order = 430;
      }
    ];

    homelab = enabled;
    nix = enabled;
  };

  # ======================== DO NOT CHANGE THIS ========================
  home.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
