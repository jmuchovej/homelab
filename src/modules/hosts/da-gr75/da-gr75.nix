{
  den,
  lib,
  __findFile,
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

    kubernetes.server-addr = "https://10.69.11.1:6443";

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

    # Export /impulse/k8s for the K8s cluster (bulk/shared data — media,
    # immich library, …). A dedicated subtree keeps minio's /impulse/s3 out
    # of the NFS export. `/impulse/k8s` must exist (e.g. `zfs create impulse/k8s`).
    nfs = {
      exports = [
        { path = "/impulse/k8s"; }
        { path = "/impulse/users"; }
        # Network home directories for the da-vcx-* hosts. Mounted as /home
        # there; survives their impermanence rollback. `/impulse/home` must
        # exist (e.g. `zfs create impulse/home`).
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

      boot.zfs.extraPools = [
        "impulse"
      ];
      system.stateVersion = "24.11";
    };
  };
}
