{ config, lib, pkgs, ...  }: {
  environment.systemPackages = [
    pkgs.file
    pkgs.bc
    pkgs.btop
    pkgs.eza
    pkgs.vim
    pkgs.git
    pkgs.wget
    pkgs.rsync
    pkgs.rclone
    pkgs.dnsutils
    pkgs.gnupg
    pkgs.fastfetch
    pkgs.home-manager
    pkgs.ipinfo
    pkgs.ipcalc
    pkgs.wget
    pkgs.pciutils
  ];
}
