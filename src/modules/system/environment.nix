# Environment: XDG, pager, locale, time, zsh.
_: {
  rbn.system._.environment = {
    # Shared across NixOS and darwin
    os =
      { lib, pkgs, ... }:
      let
        pagerArgs = [
          "--RAW-CONTROL-CHARS"
          "--wheel-lines=5"
          "--LONG-PROMPT"
          "--no-vbell"
          " --wordwrap"
        ];
      in
      {
        programs.zsh.enable = lib.mkDefault true;

        environment.variables = {
          XDG_BIN_HOME = "$HOME/.local/bin";
          XDG_CACHE_HOME = "$HOME/.cache";
          XDG_CONFIG_HOME = "$HOME/.config";
          XDG_DATA_HOME = "$HOME/.local/share";
          XDG_DESKTOP_DIR = "$HOME";
          LC_ALL = "en_US.UTF-8";

          LESSHISTFILE = "$XDG_CACHE_HOME/less.history";
          WGETRC = "$XDG_CONFIG_HOME/wgetrc";
          MANPAGER = "nvim -c 'set ft=man bt=nowrite noswapfile nobk shada=\\\"NONE\\\" ro noma' +Man! -o -";
          PAGER = "less -FR";
          LESS = lib.concatStringsSep " " pagerArgs;
        };

        environment.pathsToLink = [
          "/share/zsh"
          "/share/bash-completion"
          "/share/nix-direnv"
        ];
      };

    # NixOS-specific
    nixos =
      { lib, pkgs, ... }:
      let
        pagerArgs = [
          "--RAW-CONTROL-CHARS"
          "--wheel-lines=5"
          "--LONG-PROMPT"
          "--no-vbell"
          " --wordwrap"
        ];
      in
      {
        # ── Time ─────────────────────────────────────────────────────
        environment.systemPackages = with pkgs; [
          openntpd
          nix-zsh-completions
        ];

        networking.timeServers = [
          "0.nixos.pool.ntp.org"
          "1.nixos.pool.ntp.org"
          "2.nixos.pool.ntp.org"
          "3.nixos.pool.ntp.org"
        ];

        services.openntpd = {
          enable = true;
          extraConfig = ''
            listen on 127.0.0.1
            listen on ::1
          '';
        };

        time.timeZone = "America/New_York";

        environment.variables.LOCALE_ARCHIVE = "/run/current-system/sw/lib/locale/locale-archive";
        i18n.defaultLocale = "en_US.UTF-8";

        console = {
          font = "Lat2-Terminus16";
          keyMap = lib.mkForce "us";
        };

        # Keep classic dbus-daemon. nixpkgs flipped the default to dbus-broker,
        # which is treated as a "critical component" change and blocks live
        # `switch` activations. Pin until we can plan a reboot.
        services.dbus.implementation = "dbus";

        environment.sessionVariables.KEYTIMEOUT = 0;

        environment.variables = {
          SYSTEMD_PAGERSECURE = "true";
          SYSTEMD_LESS = lib.concatStringsSep " " (
            pagerArgs
            ++ [
              "--quit-if-one-screen"
              "--chop-long-lines"
              "--no-init"
            ]
          );
        };

        programs.zsh = {
          autosuggestions.enable = true;
          enableCompletion = true;
          histFile = "$XDG_CACHE_HOME/zsh.history";
        };
      };
  };
}
