{ lib, pkgs, ... }@args:
lib.rebellion.mk-desktop-module args {
  name = "desktop.plex";
  options = {
    player = lib.mkEnableOption "Plex Media Player";
    amp = lib.mkEnableOption "Plexamp";
  };
  conditions = { cfg, ... }: cfg.player.enable || cfg.amp.enable;
  config = _: {
    # TODO needs upstream support
    # home.packages = ([]
    #   ++ optionals cfg.player.enable [ pkgs.plex-desktop ]
    #   ++ optionals cfg.amp.enable    [ pkgs.plexamp      ]
    # );
  };
}
