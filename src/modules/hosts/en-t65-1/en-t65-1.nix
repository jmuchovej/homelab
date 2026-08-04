{ den, __findFile, ... }: {
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
