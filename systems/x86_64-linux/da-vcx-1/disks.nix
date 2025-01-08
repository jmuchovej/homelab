{ ... }: let
  btrfs-defaults = [
    "defaults"
    "compress=zstd:1"
    "ssd"
    "noatime"
    "nodiratime"
  ];
in
{
  disko.devices = {
    disk = {
      nvme0 = {
        device = "/dev/disk/by-id/nvme-Patriot_M.2_P300_256GB_P300IBBB23122507026";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            EFI = {
              priority = 1;
              type = "EF00";
              name = "EFI";
              label = "EFI";
              start = "0%";
              end = "1024MiB";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "fmask=0137"
                  "dmask=0027"
                ];
              };
            };
            root = {
              priority = 2;
              name = "NixOS";
              label = "NixOS";
              end = "-64G";

              content = {
                type = "btrfs";
                # Override existing partition
                extraArgs = [
                  "-f"
                ];
                mountOptions = [ "defaults" "discard" ];

                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = btrfs-defaults;
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = btrfs-defaults;
                  };
                };
              };
            };
            swap = {
              priority = 3;
              name = "swap";
              label = "swap";
              size = "100%";
              content = {
                type = "swap";
                randomEncryption = true;
                resumeDevice = true; # resume from hiberation from this device
                # https://github.com/nix-community/disko/issues/515#issuecomment-2063028431
                # https://github.com/nix-community/disko/issues/515#issuecomment-2381796519
                extraArgs = [ "-Lswap" ];
              };
            };
          };
        };
      };

    };
  };
}
