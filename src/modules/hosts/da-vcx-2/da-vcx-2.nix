{ __findFile, ... }:
{
  den.hosts.x86_64-linux.da-vcx-2 = {
    tailscale.enable = true;
    containers.enable = true;

    persistence = {
      device = "/dev/disk/by-id/nvme-KINGSTON_OM8PGP4512Q-A0_50026B73830175E0";
      extra-directories = [ ];
      extra-files = [ ];
    };
  };

  den.aspects.da-vcx-2 = {
    includes = [
      # Suites
      <rbn/suite/server>
      <rbn/system/boot/graphical>

      # Hardware
      <rbn/system/hardware/cpu/intel>
      <rbn/system/hardware/storage/btrfs>

      # Virtualization
      <rbn/system/virtualization>

      # Networking (base via suite-common, dns/manager selected here)
      <rbn/system/networking/dns/resolved>
      <rbn/system/networking/manager/networkd>
      <rbn/services/zerotier>

      # Services
      <rbn/services/avahi>
      <rbn/services/ldap>
    ];

    nixos = {
      networking.hostId = "4db68ea3";
      imports = [
        ./_disks.nix
      ];
      system.stateVersion = "24.11";
    };
  };
}
