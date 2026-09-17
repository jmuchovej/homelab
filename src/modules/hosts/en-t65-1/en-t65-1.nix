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
  den.hosts.x86_64-linux.en-t65-1 = {
    # STAGED — do NOT uncomment until this host can withstand root being
    # destroyed and fully reinstalled: enabling it hands the boot disk to
    # disko's btrfs @/@-blank layout, which conflicts with the live ext4 root.
    # persistence = {
    #   device = "/dev/disk/by-id/nvme-Patriot_M.2_P300_256GB_P300ABBB23101818352";
    #   extra-directories = [ ];
    #   extra-files = [ ];
    # };

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
        # backs the zfs-ssd StorageClass (and the `zfs` alias)
        "warp/k8s/pvcs" = { };
      };

    nfs.exports = [
      { path = "/impulse/k8s"; }
      { path = "/impulse/users"; }
      { path = "/impulse/home"; }
      { path = "/impulse/media"; }
    ];
  };
  den.aspects.en-t65-1 = {
    includes = [
      <rbn/suite/server>

      # Hardware
      <rbn/system/hardware/cpu/intel>
      <rbn/system/hardware/gpu/nvidia>
      <rbn/system/hardware/storage/btrfs>
      <rbn/system/hardware/storage/zfs>
      <rbn/system/hardware/storage/zfs/managed>
      <rbn/system/hardware/storage/zfs/datasets>

      # Virtualization
      <rbn/system/virtualization>

      # Security
      <rbn/system/security/sudo>
      <rbn/programs/security/sops>

      # Networking (base via suite-common, dns/manager selected here)
      <rbn/system/networking/dns/dnsmasq>
      <rbn/system/networking/manager/networkmanager>

      # Services
      <rbn/services/nfs>
      <rbn/services/kubernetes>
      <rbn/services/kubernetes/server>
      <rbn/services/ldap>
      <rbn/services/zerotier>
    ];

    provides.to-users = {
      includes = with den.aspects; [
        (facter ./facter.json)
      ];
    };

    nixos = {
      networking.hostId = "6b832704";
      boot.zfs.extraPools = [
        "impulse"
        "warp"
      ];
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
