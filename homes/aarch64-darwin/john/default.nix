{
  config,
  lib,
  namespace,
  ...
}:
let
  inherit (lib) mkDefault;

  inherit (lib.${namespace}) enabled disabled;
in
{
  rebellion = {
    user = {
      inherit (config.snowfallorg.user) name;
      enable = true;
    };

    editor = {
      neovim = mkDefault enabled;
      vscode = mkDefault enabled;
      zed = mkDefault enabled // { default = true; };
    };
    desktop = enabled // {
      wezterm = mkDefault enabled;
      # ghostty = mkDefault enabled;
      # arc     = enabled;
      appflowy  = enabled;
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

    modern-unix = {
      ssh = {
        extra-hosts = {
          git = { hostname = "git*"; identityFile = "~/.ssh/1p-%h.pub"; };
        };
        authorized-keys = [];
      };
    };
  };

  # ======================== DO NOT CHANGE THIS ========================
  home.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
