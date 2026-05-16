{ inputs, ... }:
{
  rbn.services._.proton-vpn.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) getExe getExe';
      inherit (lib.rbn) merge-deep;

      ip = getExe' pkgs.iproute2 "ip";
      ip4t = getExe' pkgs.iptables "iptables";
      ip6t = getExe' pkgs.iptables "ip6tables";

      vpn-mark = toString 42;
      vpn-table = toString 200;

      allowedIPs = [
        "0.0.0.0/0"
        "::/0"
      ];

      proton-vpn = {
        "SE-US#1" = {
          privateKeyFile = config.sops.secrets."proton/vpn/SE-US#1".path;
          peers = [
            {
              inherit allowedIPs;
              endpoint = "185.159.156.164:51820";
              publicKey = "dOF5ay40T5bp9rWkfUxeAwTa5Fd5ANdstiSjjdwwLRU=";
            }
          ];
        };
        "CH-US#3" = {
          privateKeyFile = config.sops.secrets."proton/vpn/CH-US#3".path;
          peers = [
            {
              inherit allowedIPs;
              endpoint = "79.135.104.71:51820";
              publicKey = "0abDpTVm9oXMpPL+8W495UD3BCawGKEstNO784GUaj4=";
            }
          ];
        };
      };
    in
    {
      sops.secrets."proton/vpn/SE-US#1".sopsFile = "${inputs.self}/secrets/secrets.sops.yaml";

      users.groups.proton = { };

      networking.wg-quick.interfaces.proton0 = merge-deep [
        {
          address = [ "10.2.0.2/32" ];
          dns = [ "10.2.0.1" ];
          table = "off";

          postUp = ''
            ${ip} route add default dev proton0 table ${vpn-table}
            ${ip} rule add fwmark ${vpn-mark} table ${vpn-table}
            ${ip} -6 rule add fwmark ${vpn-mark} table ${vpn-table}
            ${ip} rule add oif proton0 lookup main pref 10
            ${ip} -6 rule add oif proton0 lookup main pref 10
            ${ip4t} -t mangle -A OUTPUT -m owner --gid-owner proton -j MARK --set-mark ${vpn-mark}
            ${ip6t} -t mangle -A OUTPUT -m owner --gid-owner proton -j MARK --set-mark ${vpn-mark}
          '';

          postDown = ''
            ${ip4t} -t mangle -D OUTPUT -m owner --gid-owner proton -j MARK --set-mark ${vpn-mark} || true
            ${ip6t} -t mangle -D OUTPUT -m owner --gid-owner proton -j MARK --set-mark ${vpn-mark} || true
            ${ip} rule del fwmark ${vpn-mark} table ${vpn-table} || true
            ${ip} -6 rule del fwmark ${vpn-mark} table ${vpn-table} || true
            ${ip} rule del oif proton0 lookup main pref 10 || true
            ${ip} -6 rule del oif proton0 lookup main pref 10 || true
            ${ip} route del default dev proton0 table ${vpn-table} || true
          '';
        }
        proton-vpn."SE-US#1"
      ];

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "proton-exec" ''
          if [ -n "$SUDO_USER" ]; then
            EXEC_USER="$SUDO_USER"
          else
            EXEC_USER="$USER"
          fi
          exec ${getExe pkgs.sudo} -u "$EXEC_USER" -g proton "$@"
        '')
      ];
    };
}
