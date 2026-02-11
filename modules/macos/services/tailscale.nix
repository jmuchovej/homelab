{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.tailscale";
  config =
    { cfg, pkgs, ... }:
    {
      services.tailscale = {
        enable = true;
        package = pkgs.tailscale;
      };
    };
}
