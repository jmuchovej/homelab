{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "suites.development";
  description = "`development` suite";
  config = _: {
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
