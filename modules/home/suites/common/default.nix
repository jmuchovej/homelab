{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkDefault mkEnableOption;
  inherit (lib.${namespace}) enabled;

  cfg = config.${namespace}.suites.common;
in {
  options.${namespace}.suites.common = {
    enable = mkEnableOption "common configuration for home-manager";
  };

  config = mkIf cfg.enable {
    home.shellAliases = {
      nixcfg = "$EDITOR ~/Syncthing/${namespace}/flake.nix";
    };

    home.packages = with pkgs; [
      # Useful packages that aren't tied to specific workflows
      optinix # search ix options!
      gnupg # GPG
      age # A more modern encryption tool
      httpie # ez HTTP querying
      hyperfine # benchmarking
      erdtree # `ls`, but with directory sizes
      rust-motd # Fancy MOTD

      # Interact with JSON, YAML, and TOML data structures
      jaq
      yq-go # JQ (rust), YQ (go), and TQ (go, from YQ)
      jqp
      jnv # Do jq things, interactively

      # Generic Linux tool replacements
      parallel
      # rust-parallel   # replaces: parallel
      # https://github.com/NixOS/nixpkgs/blob/nixos-24.11/pkgs/by-name/tr/trashy/package.nix#L39
      #! TODO not supported on macOS ;(
      # broot           # replaces: ls??, tree
      choose # replaces: cut, awk
      curlie # replaces: curl
      doggo # replaces: dig
      duf # replaces: df
      dust # replaces: du
      dua # replaces: du
      gping # replaces: `ping`
      fd # replaces: find
      procs # replaces: ps
      # https://github.com/NixOS/nixpkgs/blob/nixos-24.11/pkgs/by-name/tr/trashy/package.nix#L39
      #! TODO not supported on macOS ;(
      # trashy          # replaces: rm
      ov # replaces: less, tail, more, tail
      sd # replaces: sed
      # xcp             # replaces: cp
      viddy # replaces: watch
      just # replaces: make
      ouch # replaces: unzip, tar, zip, etc.
    ];

    home.sessionVariables = {
      # Configure `ov` as the default pager
      # DELTA_PAGER = "ov -F";
      # PAGER = "ov -F -H3";
      # MANPAGER = "ov --section-delimiter '^[^\s]' --section-header";
    };

    ${namespace} = {
      programs = {
        emulators = {
          alacritty.enable = config.${namespace}.suites.desktop.enable;
          wezterm.enable = config.${namespace}.suites.desktop.enable;
          rio.enable = config.${namespace}.suites.desktop.enable;
        };
        editors = {
          neovim = mkDefault enabled;
          micro = mkDefault enabled;
        };

        shells = {
          bash = mkDefault enabled;
          nushell = mkDefault enabled;
          zsh = mkDefault enabled;
        };

        tools = {
          bat = mkDefault enabled;
          bacon = mkDefault enabled;
          bottom = mkDefault enabled;
          devenv = mkDefault enabled;
          eza = mkDefault enabled;
          fzf = mkDefault enabled;
          git = mkDefault enabled;
          ripgrep = mkDefault enabled;
          starship = mkDefault enabled;
          tmux = mkDefault enabled;
          zellij = mkDefault enabled;
          zoxide = mkDefault enabled;
        };
      };
    };

    programs.nix-index = enabled;
    programs.nix-your-shell = enabled;

    programs.readline = {
      enable = mkDefault true;

      extraConfig = ''
        set completion-ignore-case on
      '';
    };

    xdg.configFile.wgetrc.text = "";
  };
}
