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
    kernelPackages = pkgs.linuxPackages_latest;
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
