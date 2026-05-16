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
    };
}
