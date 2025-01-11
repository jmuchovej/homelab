{ ... }:
let
  defaultBtrfsOpts = [
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
        device = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP4512Q-A0_50026B73830175E0";
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
                  "f"
                  "--allow-discards"
                ];

                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = defaultBtrfsOpts;
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = defaultBtrfsOpts;
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
                # randomEncryption = true;
                # resumeDevice = true; # resume from hiberation from this device
                # https://github.com/nix-community/disko/issues/515#issuecomment-2063028431
                # https://github.com/nix-community/disko/issues/515#issuecomment-2381796519
                # extraArgs = [ "-Lswap" ];
              };
            };
          };
        };
      };

      sda = {
        device = "/dev/disk/by-id/ata-CT2000BX500SSD1_2427E8BA688C";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            root = {
              priority = 1;
              size = "100%";
              name = "impulse";
              label = "impulse";

              content = {
                type = "btrfs";
                # Override existing partition
                extraArgs = [ "-f" ];

                subvolumes = {
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = defaultBtrfsOpts;
                  };
                  "@k8s" = {
                    mountpoint = "/mnt/k8s";
                    mountOptions = defaultBtrfsOpts;
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
