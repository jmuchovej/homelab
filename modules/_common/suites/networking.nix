# Imported by platform-specific suites/networking.nix modules.
{ lib, ... }:
let
  inherit (lib) mkDefault;
  inherit (lib.rebellion) enabled;
in
{
  rebellion = {
    services.tailscale = mkDefault enabled;
    system.networking = mkDefault enabled;
  };
}
