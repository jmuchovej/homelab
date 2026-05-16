# Base NixOS networking: TCP hardening, firewall, network tools, dynamic gateway.
# DNS backend and network manager are selected via sub-aspects:
#   <rbn/system/networking/dns/dnsmasq> or <rbn/system/networking/dns/resolved>
#   <rbn/system/networking/manager/networkd> or <rbn/system/networking/manager/networkmanager>
{
  rbn.system._.networking = {
    provides.static.nixos.networking.tempAddresses = "disabled";
    provides.wol.systemd.network.links."10-wol" = {
      matchConfig.Type = "ether";
      linkConfig.WakeOnLan = "magic";
    };

    nixos =
      {
        host,
        config,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (lib)
          mkDefault
          mkForce
          optionals
          getExe'
          ;

        # Check if consul is enabled on this host (mesh services need consul)
        hasMesh = host.consul.enable or false;
      in
      {
        networking = {
          nftables.enable = true;
          wireguard.enable = true;
          firewall = {
            trustedInterfaces = [
              "virbr0"
              "podman0"
              "docker0"
            ];
            allowedUDPPorts = [ 5353 ];
            allowedTCPPorts = [
              443
              8080
            ];
            checkReversePath = mkDefault false;
            logReversePathDrops = true;
            logRefusedConnections = true;
          };

          search = [
            host.datacenter
            "lab"
          ];

          useDHCP = mkForce false;
          usePredictableInterfaceNames = mkForce true;
        };

        boot = {
          extraModprobeConfig = "options bonding max_bonds=0";

          kernelModules = [
            "af_packet"
            "tls"
            "tcp_bbr"
          ];

          kernel.sysctl = {
            # TCP hardening
            "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
            "net.ipv4.conf.default.rp_filter" = 1;
            "net.ipv4.conf.all.rp_filter" = 1;
            "net.ipv4.conf.all.accept_source_route" = 0;
            "net.ipv6.conf.all.accept_source_route" = 0;
            "net.ipv4.conf.all.send_redirects" = 0;
            "net.ipv4.conf.default.send_redirects" = 0;
            "net.ipv4.conf.all.accept_redirects" = 0;
            "net.ipv4.conf.default.accept_redirects" = 0;
            "net.ipv4.conf.all.secure_redirects" = 0;
            "net.ipv4.conf.default.secure_redirects" = 0;
            "net.ipv6.conf.all.accept_redirects" = 0;
            "net.ipv6.conf.default.accept_redirects" = 0;
            "net.ipv4.tcp_syncookies" = 1;
            "net.ipv4.tcp_rfc1337" = 1;
            "net.ipv4.conf.all.log_martians" = true;
            "net.ipv4.conf.default.log_martians" = true;
            "net.ipv4.icmp_echo_ignore_broadcasts" = true;
            "net.ipv6.conf.default.accept_ra" = 0;
            "net.ipv6.conf.all.accept_ra" = 0;
            "net.ipv4.tcp_timestamps" = 0;

            # TCP optimization
            "net.ipv4.tcp_fastopen" = 3;
            "net.ipv4.tcp_congestion_control" = "bbr";
            "net.core.default_qdisc" = "cake";

            # Buffer tuning
            "net.core.optmem_max" = 65536;
            "net.core.rmem_default" = 1048576;
            "net.core.rmem_max" = 16777216;
            "net.core.somaxconn" = 8192;
            "net.core.wmem_default" = 1048576;
            "net.core.wmem_max" = 16777216;
            "net.ipv4.ip_local_port_range" = "16384 65535";
            "net.ipv4.tcp_max_syn_backlog" = 8192;
            "net.ipv4.tcp_max_tw_buckets" = 2000000;
            "net.ipv4.tcp_mtu_probing" = 1;
            "net.ipv4.tcp_rmem" = "4096 1048576 2097152";
            "net.ipv4.tcp_slow_start_after_idle" = 0;
            "net.ipv4.tcp_tw_reuse" = 1;
            "net.ipv4.tcp_wmem" = "4096 65536 16777216";
            "net.ipv4.udp_rmem_min" = 8192;
            "net.ipv4.udp_wmem_min" = 8192;
            "net.netfilter.nf_conntrack_generic_timeout" = 60;
            "net.netfilter.nf_conntrack_max" = 1048576;
            "net.netfilter.nf_conntrack_tcp_timeout_established" = 600;
            "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = 1;
          };
        };

        environment.systemPackages = with pkgs; [
          mtr
          tcpdump
          traceroute
        ];

        # ── Dynamic gateway discovery ──────────────────────────────────
        systemd.services.discover-gateway = {
          description = "Discover default gateway and network device";
          after = [ "network-online.target" ] ++ optionals hasMesh [ "consul.service" ];
          wants = [ "network-online.target" ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };

          script =
            let
              ip = getExe' pkgs.iproute2 "ip";
              awk = getExe' pkgs.gawk "awk";
            in
            ''
              set -euo pipefail
              GATEWAY=$(${ip} route show default | ${awk} '/default/ { print $3; exit }')
              DEVICE=$(${ip} route show default | ${awk} '/default/ { print $5; exit }')

              if [ -z "$GATEWAY" ]; then
                echo "Warning: No default gateway found" >&2
                exit 1
              fi

              echo "Discovered gateway: $GATEWAY on device: $DEVICE"
              mkdir -p /run/dynamic-gateway
              cat > /run/dynamic-gateway/env <<EOF
              GATEWAY=$GATEWAY
              DEVICE=$DEVICE
              EOF
              chmod 644 /run/dynamic-gateway/env
            '';
        };

        systemd.services.dynamic-gateway = {
          description = "Configure DNS to use default gateway";
          after = [
            "network-online.target"
            "discover-gateway.service"
          ]
          ++ optionals hasMesh [ "consul.service" ];
          wants = [
            "network-online.target"
            "discover-gateway.service"
          ];
          requires = [ "discover-gateway.service" ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };

          script = mkDefault ''
            echo "No DNS backend configured"
            exit 1
          '';
        };

        systemd.services.dynamic-gateway-reload = {
          description = "Reload dynamic gateway configuration";
          serviceConfig.Type = "oneshot";
          script = ''
            ${getExe' pkgs.systemd "systemctl"} restart discover-gateway.service
            ${getExe' pkgs.systemd "systemctl"} restart dynamic-gateway.service
          '';
        };

        systemd.paths.dynamic-gateway-trigger = {
          wantedBy = [ "multi-user.target" ];
          pathConfig = {
            PathChanged = "/proc/net/route";
            Unit = "dynamic-gateway-reload.service";
          };
        };
      };

    # ── darwin networking ──────────────────────────────────────────────
    darwin = {
      networking.applicationFirewall = {
        enable = true;
        blockAllIncoming = false;
        enableStealthMode = false;
      };

      system.activationScripts.postActivation.text = ''
        echo "Checking if ssh is already loaded"
        if ! sudo launchctl list | grep -q ssh; then
          echo "Enabling ssh"
          sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist
        else
          echo "ssh is already loaded"
        fi
      '';
    };
  };
}
