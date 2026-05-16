{ __findFile, ... }:
{
  den.hosts.x86_64-linux.da-vcx-2 = {
    tailscale.enable = true;
    containers.enable = true;
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

      # Services
      <rbn/services/avahi>
      <rbn/services/ldap>
    ];

    nixos = {
      imports = [
        ./_hardware.nix
        ./_disks.nix
      ];
      system.stateVersion = "24.11";
    };
  };
}
