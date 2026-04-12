_: {
  rbn.system._.hardware._.storage._.btrfs.nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        btdu
        btrfs-assistant
        btrfs-snap
        compsize
        snapper
      ];
    };
}
