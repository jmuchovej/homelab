{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.consul";
  description = "Consul service discovery and service mesh";

  options =
    { lib, ... }:
    let
      inherit (lib.types)
        str
        int
        enum
        port
        ;
      inherit (lib.rebellion) mkopt mkopt-bool;
    in
    {
      server = mkopt-bool false "Run as Consul server (vs client)";
      bootstrap-expect = mkopt int 3 "Number of servers to wait for before bootstrapping cluster";
      interface = mkopt str "enp1s0" "Network interface to bind Consul to";
      ui = mkopt-bool true "Enable Consul web UI";

      connect = {
        enable = mkopt-bool true "Enable Consul Connect service mesh";
      };

      acl = {
        enable = mkopt-bool true "Enable ACLs";
        default-policy = mkopt (enum [
          "allow"
          "deny"
        ]) "allow" "Default ACL policy";
      };

      dns = {
        enable = mkopt-bool true "Enable DNS interface";
        port = mkopt port 8600 "DNS port";
      };

      ports = {
        http = mkopt port 8500 "HTTP API port";
        https = mkopt port 8501 "HTTPS API port";
        grpc = mkopt port 8502 "gRPC API port";
        grpc-tls = mkopt port 8503 "gRPC TLS API port";
        serf-lan = mkopt port 8301 "Serf LAN port";
        serf-wan = mkopt port 8302 "Serf WAN port";
        server = mkopt port 8300 "Server RPC port";
      };
    };

  config =
    {
      cfg,
      config,
      lib,
      pkgs,
      datacenter,
      hostname,
      peers,
      ...
    }:
    let
      inherit (lib.rebellion.network)
        with-consul
        mk-traefik-service
        mk-healthcheck
        ;

      # Generate retry-join list from datacenter peers
      retry-join-peers = map (p: "${p.hostname}.lab") peers;
    in
    lib.mkMerge [
      {
        environment.systemPackages = [ pkgs.consul ];

        services.consul = {
          enable = true;
          webUi = cfg.ui;

          # Use interface-based address detection
          interface = {
            bind = cfg.interface;
            advertise = cfg.interface;
          };

          # Force IPv4
          forceAddrFamily = "ipv4";

          extraConfig = {
            # Datacenter and node configuration
            datacenter = datacenter;
            node_name = hostname;

            # Server/Client configuration
            server = cfg.server;
          }
          // (lib.optionalAttrs cfg.server {
            bootstrap_expect = cfg.bootstrap-expect;
          })
          // (lib.optionalAttrs (retry-join-peers != [ ]) {
            retry_join = retry-join-peers;
            retry_interval = "15s";
            retry_max = 0;
          })
          // {
            # Service Mesh (Consul Connect)
            connect = lib.mkIf cfg.connect.enable {
              enabled = true;
              ca_config = {
                rotation_period = "2160h"; # 90 days
              };
            };

            # Performance tuning
            performance = {
              raft_multiplier = 1;
              leave_drain_time = "5s";
            };

            # ACL configuration
            acl = {
              enabled = cfg.acl.enable;
              default_policy = cfg.acl.default-policy;
              enable_token_persistence = true;
            };

            # DNS configuration
            ports = lib.mkIf cfg.dns.enable {
              dns = cfg.dns.port;
            };

            # Service defaults
            enable_central_service_config = true;
          };
        };

        # Firewall configuration
        networking.firewall = {
          allowedTCPPorts =
            with cfg.ports;
            [
              http
              https
              grpc
              grpc-tls
              serf-lan
              serf-wan
              server
            ]
            ++ lib.optional cfg.dns.enable cfg.dns.port;

          allowedUDPPorts =
            with cfg.ports;
            [
              serf-lan
              serf-wan
            ]
            ++ lib.optional cfg.dns.enable cfg.dns.port;
        };
      }

      # DNS integration - use dnsmasq for Consul DNS forwarding
      (lib.mkIf cfg.dns.enable {
        rebellion.system.networking.dns = "dnsmasq";
      })

      # Consul UI service registration
      (
        let
          service = mk-traefik-service {
            inherit hostname datacenter;
            port = cfg.ports.http;
            name = "consul-ui";
            subdomain = "consul";
          };
          healthcheck = mk-healthcheck service {
            route = "/v1/health/node/${hostname}";
          };
        in
        with-consul config (
          service
          // {
            checks = [ healthcheck ];
            address = "127.0.0.1";
          }
        )
      )
    ];
}
