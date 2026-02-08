{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.openbao";
  description = "OpenBao secrets management (Raft storage)";

  options =
    { lib, ... }:
    let
      inherit (lib.types)
        str
        port
        nullOr
        path
        int
        ;
      inherit (lib.rebellion) mkopt mkopt-bool;
    in
    {
      ui = mkopt-bool true "Enable OpenBao web UI";
      interface = mkopt str "enp1s0" "Network interface to bind OpenBao";
      data-dir = mkopt str "/var/lib/openbao" "Raft data directory";

      ports = {
        api = mkopt port 8200 "API port";
        cluster = mkopt port 8201 "Cluster port";
      };
    };

  config =
    {
      cfg,
      config,
      lib,
      pkgs,
      hostname,
      datacenter,
      peers,
      ...
    }:
    let
      inherit (lib.rebellion.file) get-secret;
      inherit (lib.rebellion.network)
        mk-traefik-service
        with-consul
        mk-healthcheck
        mk-authentik
        ;

      bind-addr = "{{ GetInterfaceIP \"${cfg.interface}\" }}";

      service = mk-traefik-service {
        inherit hostname datacenter;
        name = "openbao";
        subdomain = "vault";
        port = cfg.ports.api;
      };

      healthcheck = mk-healthcheck service {
        route = "/v1/sys/health";
        # OpenBao returns different codes for sealed/unsealed
        # 200 = initialized, unsealed, active
        # 429 = unsealed, standby
        # 472 = data recovery mode
        # 501 = not initialized
        # 503 = sealed
      };

      # Generate retry_join stanzas from peers (same pattern as consul.nix)
      retry-join-stanzas = map (p: {
        leader_api_addr = "http://${p.hostname}.node.consul:${toString cfg.ports.api}";
      }) peers;

      has-peers = retry-join-stanzas != [ ];

      secrets-owner = "openbao";
      secrets-group = "openbao";

    in
    lib.mkMerge [
      (get-secret config "openbao/root-token" datacenter)
      (get-secret config "openbao/admin-pass" datacenter)
      (get-secret config "openbao/unseal-key" datacenter)
      {
        users.users.openbao = {
          group = "openbao";
          isSystemUser = true;
        };
        users.groups.openbao = { };

        systemd.tmpfiles.rules = [
          "d /var/log/openbao 0755 openbao openbao -"
        ];
        sops.secrets."openbao/unseal-key" = {
          owner = secrets-owner;
          group = secrets-group;
          mode = "0640";
        };

        environment.systemPackages = [ pkgs.openbao ];

        services.openbao = {
          enable = true;
          package = pkgs.openbao;

          settings = {
            ui = cfg.ui;

            api_addr = "http://${bind-addr}:${toString cfg.ports.api}";
            cluster_addr = "https://${bind-addr}:${toString cfg.ports.cluster}";

            listener.tcp = {
              type = "tcp";
              address = "0.0.0.0:${toString cfg.ports.api}";
              cluster_address = "0.0.0.0:${toString cfg.ports.cluster}";
              tls_disable = true;
            };

            storage.raft = {
              path = cfg.data-dir;
              node_id = hostname;
              performance_multiplier = 1;
            }
            // lib.optionalAttrs has-peers {
              retry_join = retry-join-stanzas;
            };

            cluster_name = "openbao-${datacenter}";

            initialize = [
              {
                audit.request = [
                  {
                    enable-audit = {
                      operation = "update";
                      path = "sys/audit/file";
                      allow_failure = true;
                      data = {
                        type = "file";
                        options.file_path = "/var/log/openbao/audit.log";
                        options.log_raw = false;
                      };
                    };
                  }
                ];
              }
              {
                identity.request = [
                  {
                    mount-userpass = {
                      operation = "update";
                      path = "sys/auth/userpass";
                      data.type = "userpass";
                      data.path = "userpass/";
                      data.description = "userpass-authn";
                    };
                  }
                  {
                    userpass-add-admin = {
                      operation = "update";
                      path = "auth/userpass/users/admin";
                      data.password = {
                        eval_type = "string";
                        eval_source = "env";
                        env_var = "INITIAL_ADMIN_PASSWORD";
                        require_present = true;
                      };
                      data.token_policies = [ "superuser" ];
                    };
                  }
                ];
              }
              {
                policy.request = [
                  {
                    add-superuser-policy = {
                      operation = "update";
                      path = "sys/policies/acl/superuser";
                      data.policy = ''
                        path "*" {
                          capabilities = ["create", "update", "read", "delete", "list", "scan", "sudo" ]
                        }
                      '';
                    };
                  }
                  {
                    add-reader-policy = {
                      operation = "update";
                      path = "sys/policies/acl/reader";
                      data.policy = ''
                        path "*" {
                          capabilities = ["read", "list"]
                        }
                      '';
                    };
                  }
                ];
              }
            ];

            seal."static" = {
              current_key_id = "20260208-1";
              current_key = "file://${config.sops.secrets."openbao/unseal-key".path}";
            };

            telemetry = {
              prometheus_retention_time = "30s";
              disable_hostname = false;
            };
          };
        };

        systemd.services.openbao.serviceConfig = {
          LogsDirectory = secrets-owner;
          # AF_NETLINK is required for GetInterfaceIP sockaddr template
          RestrictAddressFamilies = lib.mkForce [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
            "AF_NETLINK"
          ];
          EnvironmentFile = config.sops.templates."openbao.env".path;
        };

        sops.templates."openbao.env" = {
          content = ''
            INITIAL_ADMIN_PASSWORD=${config.sops.placeholder."openbao/admin-pass"}
          '';
          owner = secrets-owner;
          group = secrets-group;
        };

        networking.firewall.allowedTCPPorts = [
          cfg.ports.api
          cfg.ports.cluster
        ];
      }

      # Consul service registration
      (
        let
          authentik-tags = mk-authentik service {
            name = "OpenBao";
            type = "oauth";
            group = "Compute";
            access = [
              "compute"
              "compute-managers"
            ];
            icon = "sh:openbao";
          };
        in
        with-consul config (
          service
          // {
            checks = [ healthcheck ];
            tags = authentik-tags;
          }
        )
      )
    ];
}
