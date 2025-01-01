{ channels, ... }:
_final: _prev: {
  inherit (channels.nixpkgs-git)
    efitools
    ;
}
