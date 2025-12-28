{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.proton-vpn";
  options =
    let
      inherit (lib.types) enum;
      inherit (lib.rebellion) mkopt;
    in
    {
      location = mkopt (enum [
        "SE-US#1"
        "CH-US#3"
      ]) "SE-US#1" "Which ProtnVPN server to use";
    };

  config =
    {
      cfg,
      config,
      lib,
      ...
    }:
    let
      inherit (lib.rebellion.file) get-file;

      allowedIPs = [
        "0.0.0.0/0"
        "::/0"
      ];
      proton-vpn."SE-US#1" = {
        privateKeyFile = config.sops.secrets."proton/vpn/SE-US#1".path;
        peers = [
          {
            inherit allowedIPs;
            endpoint = "185.159.156.164:51820";
            publicKey = "dOF5ay40T5bp9rWkfUxeAwTa5Fd5ANdstiSjjdwwLRU";
          }
        ];
      };
      proton-vpn."CH-US#3" = {
        privateKeyFile = config.sops.secrets."proton/vpn/CH-US#3".path;
        peers = [
          {
            inherit allowedIPs;
            endpoint = "79.135.104.71:51820";
            publicKey = "0abDpTVm9oXMpPL+8W495UD3BCawGKEstNO784GUaj4=";
          }
        ];
      };
    in
    {
      sops.secrets."proton/vpn/${cfg.location}".sopsFile = get-file "secrets/secrets.sops.yaml";

      networking.wireguard.interfaces.proton0 = lib.recursiveUpdate {
        ips = [ "10.2.0.2/32" ];
        extraOptions.DNS = "10.2.0.1";
      } proton-vpn."${cfg.location}";
    };
}
