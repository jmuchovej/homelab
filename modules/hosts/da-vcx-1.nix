{ __findFile, ... }:
{
  # Host schema config — read by aspects via `host.*`
  den.hosts.x86_64-linux.da-vcx-1 = {
    consul = {
      server = true;
      interface = "enp12s0";
      bootstrap-expect = 1;
    };
    keepalived = {
      enable = true;
      interface = "enp12s0";
      vip.address = "10.69.1.1";
      vip.prefix = 16;
      vrrp = {
        router-id = 42;
        priority = 242;
        preempt = false;
        advert-interval = 1;
      };
    };
    traefik = {
      enable = true;
      consul-catalog = true;
    };
    openbao = {
      enable = true;
      interface = "enp12s0";
    };
    nomad = {
      enable = true;
      server = true;
      client = true;
      bootstrap-expect = 1;
      interface = "enp12s0";
      consul.enable = true;
    };
    s3.buckets = [
      "volsync"
      "postgres"
      "authentik"
    ];
    authentik.enable = true;
    tailscale.enable = true;
    containers.enable = true;
  };

  den.aspects.da-vcx-1 = {
    includes = [
      # Suites
      <rbn/suite/server>
      <rbn/system/boot/graphical>

      # Hardware
      <rbn/system/hardware/cpu/intel>
      <rbn/system/hardware/gpu/nvidia>
      <rbn/system/hardware/storage/btrfs>
      <rbn/system/hardware/storage/zfs>
      <rbn/system/hardware/storage/zfs/managed>

      # Virtualization
      <rbn/system/virtualization>

      # Security
      <rbn/security/sudo>

      # Networking (base via suite-common, dns/manager selected here)
      <rbn/system/networking/dns/dnsmasq>
      <rbn/system/networking/manager/networkmanager>

      # Services
      <rbn/services/consul>
      <rbn/services/keepalived>
      <rbn/services/traefik>
      <rbn/services/authentik>
      <rbn/services/openbao>
      <rbn/services/nomad>
      <rbn/services/syncthing>
      <rbn/services/avahi>
      <rbn/services/cloudflared>
      <rbn/services/redis>
      <rbn/services/ldap>
      <rbn/services/chroma>
      <rbn/services/n8n>
      <rbn/services/media>
      <rbn/services/immich>
      <rbn/services/homebox>
      <rbn/services/spliit>
      <rbn/services/home-assistant>
      <rbn/services/postgres>
      <rbn/services/homepage>
      <rbn/services/proton-vpn>
      <rbn/services/qbittorrent>
      <rbn/services/s3>
      <rbn/services/split-pro>
      <rbn/services/arr>
    ];

    nixos = {
      boot.zfs.extraPools = [
        "impulse"
        "warp"
      ];
    };
  };
}
