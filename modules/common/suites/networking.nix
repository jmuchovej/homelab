{ config, lib, ... }@args:
lib.rebellion.mk-module args {
  name = "suites.networking";
  config =
    { config, lib, ... }:
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
