{
  __findFile,
  den,
  lib,
  ...
}:
let
  # The k8s Syncthing pods all run as 8384:8384 (see
  # src/kubernetes/components/syncthing/AGENTS.md); the owner reaches their own
  # tree through the ACL, so no human uid is written down here.
  sync-tree =
    key: quota:
    lib.nameValuePair "impulse/syncthing/${key}" {
      inherit quota;
      owner = "8384:8384";
      # setgid, so entries the owner creates stay group-owned by syncthing
      mode = "2770";
      acl-users = [ key ];
      properties = {
        acltype = "posixacl";
        xattr = "sa";
      };
    };
in
{
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

    kubernetes.server-addr = "https://10.32.11.1:6443";

    zfs.datasets =
      lib.mapAttrs' sync-tree {
        ypah-xuuk = "3T";
        ggms-eksu = "1T";
        gasm-egbe = "1T";
        floe-rlfn = "1T";
      }
      // {
        # backs the zfs-hdd StorageClass
        "impulse/k8s/pvcs" = { };
      };

    nfs = {
      exports = [
        { path = "/impulse/k8s"; }
        { path = "/impulse/users"; }
        { path = "/impulse/home"; }
        { path = "/impulse/media"; }
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
      <rbn/system/hardware/storage/zfs/datasets>

      # Security
      <rbn/system/security/sudo>

      # Networking (base via suite-common, dns/manager selected here)
      <rbn/system/networking/dns/dnsmasq>
      <rbn/system/networking/manager/networkmanager>

      # Services
      <rbn/services/nfs>
      <rbn/services/kubernetes>
      <rbn/services/kubernetes/client>
      <rbn/services/avahi>
      <rbn/services/ldap>
      <rbn/services/zerotier>
    ];

    provides.to-users = {
      includes = with den.aspects; [
        (facter ./facter.json)
      ];
    };

    nixos = {
      networking.hostId = "15b9a7a8";
      boot.zfs.extraPools = [ "impulse" ];
      system.stateVersion = "24.11";
    };
  };
}
