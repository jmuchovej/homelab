{
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "ssd"
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

  fileSystems."/home" = {
    device = "/dev/disk/by-partlabel/impulse";
    fsType = "btrfs";
    options = [
      "rw"
      "noatime"
      "compress-force=zstd:1"
      "ssd"
      "subvol=/@home"
    ];
  };

  fileSystems."/mnt/k8s" = {
    device = "/dev/disk/by-partlabel/impulse";
    fsType = "btrfs";
    options = [
      "rw"
      "nodatacow"
      "noatime"
      "compress-force=zstd:1"
      "ssd"
      "subvol=/@k8s"
    ];
  };

  hardware.enableRedistributableFirmware = true;
}
