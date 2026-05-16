{ inputs, lib, ... }:
{
  flake-file.inputs = {
    impermanence.url = "github:nix-community/impermanence";
  };

  den.default.nixos = {
    imports = [
      inputs.impermanence.nixosModules.impermanence
    ];

    fileSystems."/persist" = {
      neededForBoot = true; # so it's mounted before activation
      fsType = "btrfs";
    };

    boot.initrd.systemd.services.rollback = {
      description = "Roll @ back to @-blank on every boot";
      wantedBy = [ "initrd.target" ];
      after = [ "dev-disk-by\\x2dpartlabel-NixOS.device" ];
      before = [ "sysroot.mount" ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /mnt
        mount -o subvol=/ /dev/disk/by-partlabel/NixOS /mnt

        # If anything created nested subvols under @, kill them first
        btrfs subvolume list -o /mnt/@ | cut -f9 -d' ' | while read sv; do
          btrfs subvolume delete "/mnt/$sv"
        done

        btrfs subvolume delete /mnt/@
        btrfs subvolume snapshot /mnt/@-blank /mnt/@

        umount /mnt
      '';
    };

    environment.persistence."/persist" = {
      hideMounts = true;
      directories = [
        "/etc/nixos"
        "/var/log"
        "/var/lib/nixos"
      ];
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };
  };
}
