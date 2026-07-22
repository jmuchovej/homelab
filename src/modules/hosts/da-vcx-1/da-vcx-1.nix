{
  lib,
  den,
  __findFile,
  ...
}:
{
  # Host schema config — read by aspects via `host.*`
  den.hosts.x86_64-linux.da-vcx-1 = {
    s3 = {
      buckets = [
        "volsync"
        "postgres"
        "authentik"
      ];
      data-dir = [ "/impulse/s3" ];
    };
    authentik.enable = true;
    containers.enable = true;

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
      # <rbn/system/virtualization>
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
      # (<rbn/services/kubernetes>); only per-host infrastructure remains
      <rbn/services/nfs>
      <rbn/services/kubernetes>
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

      boot.zfs.extraPools = [
        "warp"
      ];
      system.stateVersion = "24.11";
    };
  };
}
