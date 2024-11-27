{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = [
    pkgs.zfs
    pkgs.nfs-utils
  ];
}
