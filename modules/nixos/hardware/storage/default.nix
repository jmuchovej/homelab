{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkDefault mkEnableOption;

  cfg = config.${namespace}.hardware.storage;
in
{
  options.${namespace}.hardware.storage = {
    enable = mkEnableOption "extra storage devices";
    ssd = {
      enable = mkEnableOption "enable support for SSDs" // { default = true; };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      fuseiso
      nfs-utils
      ntfs3g
    ];

    services.fstrim.enable = mkDefault cfg.ssd.enable;
  };
}
