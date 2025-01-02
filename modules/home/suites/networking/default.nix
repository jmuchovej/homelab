{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  inherit (pkgs.stdenv) isLinux isDarwin;

  cfg = config.${namespace}.suites.networking;
in
{
  options.${namespace}.suites.networking = {
    enable = mkEnableOption "`networking` suite";
  };

  config = mkIf cfg.enable {

    home.packages =
      with pkgs;
      [
        nmap
        openssh
        speedtest-cli
        ssh-copy-id
      ]
      ++ lib.optionals isLinux [ iproute2 ];
  };
}
