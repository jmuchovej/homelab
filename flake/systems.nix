{
  inputs,
  self,
  lib,
  ...
}:
let
  inherit (self.lib.file) parse-system-configurations filter-nixos-systems filter-macos-systems;

  systems-path = ../systems;
  all-systems = parse-system-configurations systems-path;
in
{
  flake = {
    nixosConfigurations = lib.mapAttrs' (
      _name:
      { system, hostname, ... }:
      {
        name = hostname;
        value = self.lib.system.nixos {
          inherit inputs system hostname;
          username = "john";
        };
      }
    ) (filter-nixos-systems all-systems);

    darwinConfigurations = lib.mapAttrs' (
      _name:
      { system, hostname, ... }:
      {
        name = hostname;
        value = self.lib.system.macos {
          inherit inputs system hostname;
          username = "john";
        };
      }
    ) (filter-macos-systems all-systems);
  };
}
