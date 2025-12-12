{
  config,
  lib,
  pkgs,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkDefault mkEnableOption;

  cfg = config.rebellion.suites.common;
in {
  options.rebellion.suites.common = {
    enable = mkEnableOption "`common` configuration";
  };

  config = mkIf cfg.enable {
    programs.zsh.enable = mkDefault true;

    environment.systemPackages = with pkgs; [
      coreutils
      curl
      fd
      file
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
