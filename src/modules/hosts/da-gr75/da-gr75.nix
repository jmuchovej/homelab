{ den, __findFile, ... }:
{
  # Host schema config — read by aspects via `host.*`
  den.hosts.x86_64-linux.da-gr75 = {
    s3 = {
      buckets = [
        "volsync"
        "postgres"
        "authentik"
      ];
      data-dir = [ "/impulse/s3" ];
    };
    persistence = {
      device = "/dev/disk/by-id/nvme-TEAM_TM8FP6256G_TPBF2305040040102039";
      extra-directories = [ ];
      extra-files = [ ];
    };
    nfs = {
      exports = [
        { path = "/impulse/k8s"; }
        { path = "/impulse/users"; }
        { path = "/impulse/home"; }
      ];
    };
  };

  den.aspects.da-gr75 = {
    includes = [

      # Suites
      <rbn/suite/server>
      <rbn/system/boot/graphical>

      # Hardware
      <rbn/system/hardware/cpu/intel>
      <rbn/system/hardware/storage/btrfs>
      <rbn/system/hardware/storage/zfs>
      <rbn/system/hardware/storage/zfs/managed>

      # Security
      <rbn/system/security/sudo>

      # Networking (base via suite-common, dns/manager selected here)
      <rbn/system/networking/dns/dnsmasq>
      <rbn/system/networking/manager/networkmanager>

      # Services
      <rbn/services/nfs>
      <rbn/services/avahi>
      <rbn/services/ldap>
      <rbn/services/postgres>
      <rbn/services/zerotier>
    ];

    provides.to-users = {
      includes = with den.aspects; [
        (facter ./facter.json)
      ];
    };

    nixos = {
      networking.hostId = "15b9a7a8";

      boot.zfs.extraPools = [
        "impulse"
      ];
      system.stateVersion = "24.11";
    };
  };
}
