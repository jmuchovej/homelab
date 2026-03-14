{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.brave";
  config = _: {
    programs.brave = {
      enable = true;

      # https://discourse.nixos.org/t/home-manager-ungoogled-chromium-with-extensions/15214
      # https://github.com/nix-community/home-manager/issues/2216#issuecomment-917507881
      # https://github.com/NixOS/nixpkgs/pull/98014
      # extensions = with pkgs.chromium-extensions; [
      # ];
    };

    rebellion.dock.entries = [
      {
        name = "Brave Browser.app";
        source = "hm";
        group = "browsers";
        order = 310;
      }
    ];
  };
}
