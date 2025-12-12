{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (lib.rebellion) enabled disabled;
in
{
  imports = [
    ./disks.nix
    ./hardware.nix
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
        defaultSopsFile = ./secrets.sops.yaml;
      };
    };

    services = {
      ldap = enabled;
      openssh = enabled;
      syncthing = enabled;
      tailscale = enabled;
    };

    nix = enabled;

    system = {
      boot = enabled // {
        plymouth = enabled;
        secure-boot = disabled;
        silent-boot = enabled;
      };
      locale = enabled;
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
