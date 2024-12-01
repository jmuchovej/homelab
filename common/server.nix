{ config, lib, pkgs, outputs, ... }: {
  imports = [
    ./default.nix

    ./users/lab.nix

    ./modules/chrony.nix
    ./modules/terminal.nix
    ./modules/network.nix
    ./modules/ldap.nix
    ./modules/openssh.nix
    ./modules/zerotier.nix
    ./modules/filesystem.nix

    ./optional/podman.nix
    ./optional/reboot-required.nix
    ./optional/virtualization.nix
  ];

  services.openssh = {
    enable = true;
  }
}
