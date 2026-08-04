{ den, __findFile, ... }: {
  den.hosts.x86_64-linux.da-vcx-1 = {
    s3 = {
      buckets = [
        "volsync"
        "postgres"
        "authentik"
      ];
      data-dir = [ "/impulse/s3" ];
    };

    nfs.mounts = [
      {
        server = "10.69.10.1";
        remote = "/impulse/home";
        local = "/home";
      }
      {
        server = "10.69.10.1";
        remote = "/impulse/media";
        local = "/srv/media";
      }
    ];

    persistence = {
      device = "/dev/disk/by-id/nvme-Patriot_M.2_P300_256GB_P300IBBB23122507026";
      extra-directories = [ ];
      extra-files = [ ];
    };

    zfs.datasets = {
      # backs the default zfs-ssd StorageClass (and its deprecated `zfs` alias)
      "warp/k8s/pvcs" = { };
    };
  };

  den.aspects.da-vcx-1 = {
    includes = [
      # Suites
      <rbn/suite/common>
      <rbn/suite/development>
      <rbn/suite/server>

      <rbn/system/boot/graphical>
      # Hardware
      <rbn/system/hardware/cpu/intel>
      <rbn/system/hardware/gpu/nvidia>
      <rbn/system/hardware/storage/btrfs>
      <rbn/system/hardware/storage/zfs>
      <rbn/system/hardware/storage/zfs/managed>
      <rbn/system/hardware/storage/zfs/datasets>

      # Virtualization
      <rbn/system/virtualization/apptainer>
      <rbn/system/virtualization/apptainer/nvidia>
      # (<rbn/system/virtualization/win11> {
      #   vhd = "/warp/vms/win11.qcow2";
      #   vcpus = 8;
      #   memory = 32; # GiB
      #   gpu = "0000:01:00.0"; # RTX 3090 — VGA .0 + HDMI-audio .1
      # })

      # Security
      <rbn/system/security/sudo>

      # Networking (base via suite-common, dns/manager selected here)
      <rbn/system/networking/dns/dnsmasq>
      <rbn/system/networking/manager/networkmanager>

      # Services — the app tier lives in the cluster now
      <rbn/services/nfs>
      <rbn/services/kubernetes>
      <rbn/services/kubernetes/server>
      <rbn/services/kubernetes/nvidia>
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
      networking.hostId = "fe4ccbf4";
      boot.zfs.extraPools = [ "warp" ];
      system.stateVersion = "24.11";
    };
  };
}
