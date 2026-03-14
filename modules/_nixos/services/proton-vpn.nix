{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.proton-vpn";
  options =
    let
      inherit (lib.types) enum;
      inherit (lib.rebellion.options) mk;
    in
    {
      location = mk (enum [
        "SE-US#1"
        "CH-US#3"
      ]) "SE-US#1" "Which ProtonVPN server to use";
    };

  config =
    {
      cfg,
      config,
      lib,
      ...
    }:
    let
      inherit (lib.rebellion.fs) get-secret';
      inherit (lib.rebellion) attrs;
      inherit (lib) getExe getExe';

      ip = getExe' pkgs.iproute2 "ip";
      ip4t = getExe' pkgs.iptables "iptables";
      ip6t = getExe' pkgs.iptables "ip6tables";

      vpn-mark = toString 42;
      vpn-table = toString 200;

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
            publicKey = "dOF5ay40T5bp9rWkfUxeAwTa5Fd5ANdstiSjjdwwLRU=";
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
    lib.mkMerge [
      (get-secret' config "proton/vpn/${cfg.location}")
      {

        # Create 'vpn' group for policy-based routing
        users.groups.proton = { };

        # Policy-based routing: route traffic from 'vpn' group through proton0
        networking.wg-quick.interfaces.proton0 = attrs.merge-deep [
          {
            address = [ "10.2.0.2/32" ];
            dns = [ "10.2.0.1" ];

            table = "off";

            # Setup policy-based routing after interface comes up
            postUp = ''
              # Create separate routing table for proton traffic
              ${ip} route add default dev proton0 table ${vpn-table}

              # Rule: packets with mark ${vpn-mark} use proton table
              ${ip} rule add fwmark ${vpn-mark} table ${vpn-table}
              ${ip} -6 rule add fwmark ${vpn-mark} table ${vpn-table}

              # Prevent proton interface traffic from being marked (avoid loops)
              ${ip} rule add oif proton0 lookup main pref 10
              ${ip} -6 rule add oif proton0 lookup main pref 10

              # Mark packets from 'proton' group with fwmark ${vpn-mark}
              ${ip4t} -t mangle -A OUTPUT -m owner --gid-owner proton -j MARK --set-mark ${vpn-mark}
              ${ip6t} -t mangle -A OUTPUT -m owner --gid-owner proton -j MARK --set-mark ${vpn-mark}
            '';

            # Cleanup when interface goes down
            postDown = ''
              ${ip4t} -t mangle -D OUTPUT -m owner --gid-owner proton -j MARK --set-mark ${vpn-mark} || true
              ${ip6t} -t mangle -D OUTPUT -m owner --gid-owner proton -j MARK --set-mark ${vpn-mark} || true

              ${ip} rule del fwmark ${vpn-mark} table ${toString vpn-table} || true
              ${ip} -6 rule del fwmark ${vpn-mark} table ${toString vpn-table} || true

              ${ip} rule del oif proton0 lookup main pref 10 || true
              ${ip} -6 rule del oif proton0 lookup main pref 10 || true

              ${ip} route del default dev proton0 table ${vpn-table} || true
            '';
          }
          proton-vpn."${cfg.location}"
        ];

        # Wrapper script to run programs through VPN
        environment.systemPackages = [
          (pkgs.writeShellScriptBin "proton-exec" ''
            # Determine current user
            if [ -n "$SUDO_USER" ]; then
              EXEC_USER="$SUDO_USER"
            else
              EXEC_USER="$USER"
            fi

            # Run command as current user but in 'vpn' group
            exec ${getExe pkgs.sudo} -u "$EXEC_USER" -g proton "$@"
          '')
        ];
      }
    ];
}
