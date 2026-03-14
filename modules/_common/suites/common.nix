# This is mostly sugar. `common` is the base configuration _always_ present on any OS I control.
# Imported by platform-specific suites/common.nix modules.
{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkDefault;
in
{
  programs.zsh.enable = mkDefault true;

  environment.systemPackages = with pkgs; [
    coreutils
    curl
    fd
    file
    git
    findutils
    lsof
    pciutils
    tldr
    unzip
    wget
    xclip
  ];
}
