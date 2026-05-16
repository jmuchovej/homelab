_:
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
