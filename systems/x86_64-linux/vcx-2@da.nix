{
  lib,
  ...
}:
let
  inherit (lib.rebellion) enabled disabled;
in
{
  imports = [
    (./. + "/vcx-2@da/disks.part.nix")
    (./. + "/vcx-2@da/hardware.part.nix")
  ];

  topology.self = {
    name = "🚀 da-vcx-2";
    hardware.info = "Intel i5-12600H; 32GB RAM";
  };

  rebellion = {
    hardware = {
      cpu.intel = enabled;
      storage = enabled // {
        ssd = enabled;
        btrfs = enabled;
      };
    };

    security = {
      doas = enabled;
      sops = enabled // {
        # default-sops-file = ./secrets.sops.yaml;
      };
    };

    services = {
      ldap = enabled;
      openssh = enabled;
      # syncthing = enabled;
      tailscale = enabled;
    };

    system = {
      boot.plymouth = enabled;
      boot.secure-boot = disabled;
      boot.silent-boot = enabled;
      networking = enabled;
    };

    virtualization = {
      containers = enabled;
    };

    suites = {
      server = enabled;
    };
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
