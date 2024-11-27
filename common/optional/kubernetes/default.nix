{ config, lib, pkgs, ... }: {
  imports = [
    ./firewall.nix
    ./master.nix
    ./worker.nix
  ];
}
