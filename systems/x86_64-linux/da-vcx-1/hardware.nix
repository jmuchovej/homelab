{
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.hostId = "1f49a11f";

  boot = {
    # TODO ZFS 2.3 only supports up to 6.13!
    # kernelPackages = pkgs.linuxPackages_latest;
    # Latest LTS from https://kernel.org
    kernelPackages = pkgs.linuxPackages_6_12;
    initrd.availableKernelModules = [
      "xhci_pci"
      "mpt3sas"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/EFI";
    fsType = "vfat";
    options = [
      "fmask=0137"
      "dmask=0027"
    ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-partlabel/NixOS";
    fsType = "btrfs";
    options = [
      "rw"
      "noatime"
      "ssd"
      "subvol=/@"
    ];
  };

  swapDevices = [
    { device = "/dev/disk/by-partlabel/swap"; }
  ];

  hardware.enableRedistributableFirmware = true;
}
