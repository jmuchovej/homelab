{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkDefault mkEnableOption;

  cfg = config.rebellion.suites.common;
in
{
  # This is mostly sugar. `common` is the base configuration _always_ present on any OS I control.
  options.rebellion.suites.common = {
    enable = mkEnableOption "`common` configuration" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
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
  };
}
