{
  cfg,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf mkForce;
in
mkIf (cfg.manager == "systemd-networkd") {
  networking.useNetworkd = mkForce true;

  # https://wiki.nixos.org/wiki/Systemd-networkd
  systemd.network = {
    enable = true;

    wait-online = {
      enable = false;
      anyInterface = true;
      extraArgs = [ "--ipv4" ];
    };

    # https://wiki.archlinux.org/title/Systemd-networkd
    networks = {
      # leave the kernel dummy devies unmanaged
      "10-dummy" = {
        matchConfig.Name = "dummy*";
        networkConfig = { };
        # linkConfig.ActivationPolicy = "always-down";
        linkConfig.Unmanaged = "yes";
      };

      # let me configure tailscale manually
      "20-tailscale-ignore" = mkIf config.rebellion.services.tailscale.enable {
        matchConfig.Name = "tailscale*";
        linkConfig = {
          Unmanaged = "yes";
          RequiredForOnline = false;
        };
      };
    };
  };
}
