{
  inputs,
  den,
  lib,
  ...
}:
let
  persistence-class =
    { host }:
    { class, aspect-chain }:
    den.batteries.forward {
      each = lib.optional (host.class == "nixos" && host.persistence != null) true;
      fromClass = _: "persistence";
      intoClass = _: class;
      intoPath = _: [ ];
      fromAspect = _: lib.head aspect-chain;
    };

  btrfs-defaults = [
    "defaults"
    "compress=zstd:1"
    "ssd"
    "noatime"
    "nodiratime"
  ];
in
{
  flake-file.inputs.impermanence.url = "github:nix-community/impermanence";

  # The `host.persistence` typed option is declared for all hosts (the
  # schema-level filter on host.class triggers an infinite recursion since
  # reading config.class requires option resolution). Darwin hosts that
  # accidentally set host.persistence get the data ignored — the class's
  # `each` filter above refuses to forward for anything that isn't nixos.
  #
  # `includes` and `options` are siblings of the same attrset because the
  # function-form (`den.schema.host = { lib, ... }: …`) makes the value a
  # function, and you can't assign `.includes` onto a function. `lib` is
  # available from the file-level args above, so no wrapper is needed.
  den.schema.host = {
    includes = [ persistence-class ];

    options.persistence = lib.mkOption {
      description = ''
        Setting this attribute activates @/@-blank impermanence rollback on
        initrd boot, mounts /persist as a btrfs subvolume, and seeds
        environment.persistence."/persist" with baseline files/dirs
        (machine-id, SSH host keys, /etc/nixos, /var/log). Hosts add state
        directories they need to survive the rollback via
        `extra-directories`. Leaving this null is the opt-out.

        Only meaningful for `host.class == "nixos"`; setting on darwin
        hosts is silently ignored.
      '';
      default = null;
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            partlabel = lib.mkOption {
              type = lib.types.str;
              default = "NixOS";
              description = "GPT partlabel of the btrfs holding @/@-blank/@nix/@persist.";
            };

            device = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                If set (typically `/dev/disk/by-id/nvme-<…>`), disko provisions
                the rebellion's standard M.2 layout on this device: EFI
                (1 GiB) + btrfs root (with @ / @-blank / @nix / @persist) +
                swap reserved at the end. Hosts that need a custom or
                multi-disk layout for the primary should leave this null and
                write their own `_disks.nix`. Hosts with the standard layout
                PLUS additional disks set this AND keep an `_disks.nix` for
                the secondary disks only (different disko-key, no collision).
              '';
            };

            swap-size = lib.mkOption {
              type = lib.types.str;
              default = "64G";
              description = "Size reserved at the end of `device` for the swap partition.";
            };

            extra-directories = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Per-host directories to persist on /persist, on top of defaults.";
            };

            extra-files = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Per-host files to persist on /persist, on top of defaults.";
            };
          };
        }
      );
    };
  };

  # Centralized impermanence content — sits in every nixos host's aspect
  # chain, but only gets forwarded to nixos config when the class's `each`
  # fires (i.e. host.class == "nixos" AND host.persistence != null).
  den.default.persistence =
    { host, ... }:
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];

      boot.initrd.systemd.services.rollback = {
        description = "Roll @ back to @-blank on every boot";
        wantedBy = [ "initrd.target" ];
        after = [ "dev-disk-by\\x2dpartlabel-${host.persistence.partlabel}.device" ];
        before = [ "sysroot.mount" ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = ''
          mkdir -p /mnt
          mount -o subvol=/ /dev/disk/by-partlabel/${host.persistence.partlabel} /mnt

          btrfs subvolume list -o /mnt/@ | cut -f9 -d' ' | while read sv; do
            btrfs subvolume delete "/mnt/$sv"
          done

          btrfs subvolume delete /mnt/@
          btrfs subvolume snapshot /mnt/@-blank /mnt/@

          umount /mnt
        '';
      };

      fileSystems."/persist" = {
        neededForBoot = true;
        fsType = "btrfs";
      };

      environment.persistence."/persist" = {
        hideMounts = true;
        directories = [
          "/etc/nixos"
          "/var/log"
          "/var/lib/nixos"
        ]
        ++ host.persistence.extra-directories;
        files = [
          "/etc/machine-id"
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ]
        ++ host.persistence.extra-files;
      };

      sops.age.sshKeyPaths = lib.mkBefore [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
      # Standard M.2 disko layout — only when host.persistence.device is set.
      # Hosts with custom partitioning leave `.device = null` and write
      # their own `_disks.nix`. `lib.mkIf` on `disko` short-circuits the
      # whole sub-tree when device is null; `mkDefault` on the disk entry
      # lets a host override individual partitions via their own _disks.nix
      # if they need to.
      disko = lib.mkIf (host.persistence.device != null) {
        devices.disk.nvme0 = lib.mkDefault {
          device = host.persistence.device;
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
                name = host.persistence.partlabel;
                label = host.persistence.partlabel;
                end = "-${host.persistence.swap-size}";
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  mountOptions = [
                    "defaults"
                    "discard"
                  ];

                  subvolumes = {
                    "@" = {
                      mountpoint = "/";
                      mountOptions = btrfs-defaults;
                    };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = btrfs-defaults;
                    };
                    "@persist" = {
                      mountpoint = "/persist";
                      mountOptions = btrfs-defaults;
                    };
                  };

                  # Seed @-blank from the just-created (empty) @ so the
                  # initrd rollback service has something to snapshot from.
                  # Without this, first boot deletes @ and emergency-modes.
                  postCreateHook = ''
                    MNT=$(mktemp -d)
                    mount -t btrfs -o subvol=/ /dev/disk/by-partlabel/${host.persistence.partlabel} "$MNT"
                    trap 'umount "$MNT"; rmdir "$MNT"' EXIT
                    btrfs subvolume snapshot -r "$MNT/@" "$MNT/@-blank"
                  '';
                };
              };

              swap = {
                priority = 3;
                name = "swap";
                label = "swap";
                size = "100%";
                content.type = "swap";
              };
            };
          };
        };
      };
    };
}
