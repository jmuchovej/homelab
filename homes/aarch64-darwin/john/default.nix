{
  config,
  lib,
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

    ssh = {
      extra-hosts = {
        git = { host = "git*"; identitiesOnly = true; identityFile = "~/.ssh/1p-%h.pub"; };
      };
      authorized-keys = [];
    };

    homelab = enabled;
    nix = disabled;
  };

  # ======================== DO NOT CHANGE THIS ========================
  home.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
