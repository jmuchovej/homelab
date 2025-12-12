{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkDefault mkEnableOption;

  cfg = config.rebellion.hardware.storage;
in
{
  options.rebellion.hardware.storage = {
    enable = mkEnableOption "extra storage devices";
    ssd = {
      enable = mkEnableOption "support for SSDs" // {
        default = true;
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      btrfs-progs
      fuseiso
      nfs-utils
      ntfs3g
    ];

    services.fstrim.enable = mkDefault cfg.ssd.enable;
  };
}
