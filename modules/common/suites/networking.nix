{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "suites.networking";
  config =
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
    };
}
