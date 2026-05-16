{ pkgs, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.hostId = "fe4ccbf4";
  networking.hostName = "da-vcx-1";

  boot = {
    # TODO ZFS 2.3 only supports up to 6.17!
    # https://github.com/NixOS/nixpkgs/blob/nixos-25.11/pkgs/os-specific/linux/zfs/2_3.nix
    # Latest from https://kernel.org
    # kernelPackages = pkgs.linuxPackages_latest;
    # https://nixos.org/manual/nixos/unstable/index.html#sec-kernel-config
    # kernelPackages = pkgs.linuxKernels.packages.linux_6_12;
    # https://nixos.org/manual/nixos/unstable/index.html#sec-linux-zfs
    kernelPackages = pkgs.linuxPackages;
    initrd.availableKernelModules = [
      "xhci_pci"
      "mpt3sas"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
  };

  hardware.enableRedistributableFirmware = true;
}
