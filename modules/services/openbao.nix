_: {
  # ── Host schema: openbao options ───────────────────────────────────
  den.schema.host =
    { lib, ... }:
    let
      inherit (lib) mkEnableOption mkOption;
      inherit (lib.types) str port;
    in
    {
      options.openbao = {
        enable = mkEnableOption "OpenBao secrets management";
        ui = mkOption {
          type = lib.types.bool;
          default = true;
        };
        interface = mkOption {
          type = str;
          default = "enp1s0";
        };
        data-dir = mkOption {
          type = str;
          default = "/var/lib/openbao";
        };
        ports = {
          api = mkOption {
            type = port;
            default = 8200;
          };
          cluster = mkOption {
            type = port;
            default = 8201;
          };
        };
      };
    };

  # ── Aspect ─────────────────────────────────────────────────────────
  rbn.services._.openbao.nixos =
    {
      host,
      config,
      lib,
      pkgs,
      peers,
      ...
    }:
    let
      inherit (lib) mkForce mkMerge optionalAttrs;
      inherit (lib.rbn)
        get-secret
        mk-traefik-service
        with-consul
        mk-healthcheck
        mk-authentik
        ;
      inherit (host) hostname datacenter;

      cfg = host.openbao;

      bind-addr = "{{ GetInterfaceIP \"${cfg.interface}\" }}";

      service = mk-traefik-service {
        inherit hostname datacenter;
        name = "openbao";
        subdomain = "vault";
        port = cfg.ports.api;
      };

      healthcheck = mk-healthcheck service {
        route = "/v1/sys/health";
      };

      retry-join-stanzas = map (p: {
        leader_api_addr = "http://${p.hostname}.node.consul:${toString cfg.ports.api}";
      }) peers;

      has-peers = retry-join-stanzas != [ ];

      secrets-owner = "openbao";
      secrets-group = "openbao";
    in
    lib.mkIf cfg.enable (mkMerge [
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
            inherit (cfg) ui;

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
            // optionalAttrs has-peers {
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
          RestrictAddressFamilies = mkForce [
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
    ]);
}
