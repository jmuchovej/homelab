{
  __findFile,
  lib,
  den,
  ...
}:
{
  # Host schema config — read by aspects via `host.*`
  den.hosts.x86_64-linux.en-t65-1 = {
    consul = {
      server = true;
      interface = "eno1";
      bootstrap-expect = 1;
    };
    keepalived = {
      enable = true;
      interface = "eno1";
      vip.address = "10.69.1.1";
      vip.prefix = 16;
      vrrp = {
        router-id = 53;
        priority = 254;
        preempt = false;
        advert-interval = 1;
      };
    };
    traefik = {
      enable = true;
      consul-catalog = true;
    };
    tailscale.enable = true;
  };

  den.aspects.en-t65-1 = {
    includes = [
      <rbn/suite/server>

      # Hardware
      <rbn/system/hardware/cpu/intel>
      <rbn/system/hardware/gpu/nvidia>

      # Virtualization
      <rbn/system/virtualization>

      # Security
      <rbn/system/security/sudo>

      <rbn/programs/security/sops>

      # Networking (base via suite-common, dns/manager selected here)
      <rbn/system/networking/dns/dnsmasq>
      <rbn/system/networking/manager/networkmanager>

      # Services
      <rbn/services/consul>
      <rbn/services/keepalived>
      <rbn/services/traefik>
      # <rbn/services/openbao>
      # <rbn/services/nomad>
      <rbn/services/home-assistant>
      <rbn/services/postgres>
    ];

    provides.to-users = {
      includes = with den.aspects; [
        (facter ./facter.json)
      ];
    };

    nixos = {
      networking.hostId = "6b832704";

      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-label/BOOT-EFI";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      swapDevices = [
        { device = "/dev/disk/by-label/swap"; }
      ];

      system.stateVersion = "24.05";
    };
  };
}
