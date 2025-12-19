{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.rebellion.suites.development;
in
{
  options.rebellion.suites.development = {
    enable = mkEnableOption "`development` suite";
  };

  config = mkIf cfg.enable {
    # apps.neovim.enable = true;
    # apps.tools.direnv.enable = true;

    # apps.misc.enable = true;

    # home.configFile."nix-init/config.toml".text = ''
    #   maintainers = ["jmuchovej"]
    #   commit = true
    # '';

    environment.systemPackages = with pkgs; [
      # Nix Utils
      nix-index
      nix-init
      nix-melt
      nix-update
      nixpkgs-fmt
      nixpkgs-hammering
      nixpkgs-review
      nurl
    ];
  };
}
