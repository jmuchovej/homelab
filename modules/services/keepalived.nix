_: {
  # ── Host schema: keepalived options ────────────────────────────────
  den.schema.host =
    { lib, ... }:
    let
      inherit (lib) mkEnableOption mkOption;
      inherit (lib.types)
        str
        int
        bool
        listOf
        ;
    in
    {
      options.keepalived = {
        enable = mkEnableOption "Keepalived VIP failover";
        interface = mkOption {
          type = str;
          default = "enp1s0";
          description = "Network interface for VIP";
        };
        vip = {
          address = mkOption {
            type = str;
            default = "10.69.1.1";
          };
          prefix = mkOption {
            type = int;
            default = 16;
          };
        };
        vrrp = {
          router-id = mkOption {
            type = int;
            default = 51;
          };
          priority = mkOption {
            type = int;
            default = 100;
          };
          preempt = mkOption {
            type = bool;
            default = false;
          };
          advert-interval = mkOption {
            type = int;
            default = 1;
          };
        };
        checks = {
          consul = mkOption {
            type = bool;
            default = true;
          };
          traefik = mkOption {
            type = bool;
            default = true;
          };
          custom = mkOption {
            type = listOf str;
            default = [ ];
          };
        };
      };
    };

  # ── Aspect ─────────────────────────────────────────────────────────
  rbn.services._.keepalived.nixos =
    {
      host,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (host) hostname;
      inherit (lib)
        getExe
        getExe'
        optional
        optionalAttrs
        ;

      cfg = host.keepalived;

      curl = getExe pkgs.curl;
      bash = getExe pkgs.bash;
      systemd-cat = getExe' pkgs.systemd "systemd-cat";

      vip-cidr = "${cfg.vip.address}/${toString cfg.vip.prefix}";
    in
    lib.mkIf cfg.enable {
      # VRRP firewall rules (nftables-compatible)
      networking.firewall.extraInputRules = ''
        ip protocol vrrp accept comment "keepalived VRRP"
        ip protocol ah accept comment "keepalived AH"
      '';

      services.keepalived = {
        enable = true;
        openFirewall = false;
        enableScriptSecurity = true;

        vrrpScripts =
          { }
          // optionalAttrs cfg.checks.consul {
            check-consul = {
              script = "${curl} -sf http://127.0.0.1:8500/v1/status/leader";
              interval = 2;
              timeout = 2;
              weight = 2;
              fall = 3;
              rise = 2;
              user = "root";
            };
          }
          // optionalAttrs cfg.checks.traefik {
            check-traefik = {
              script = "${curl} -sf http://127.0.0.1:8080/ping";
              interval = 2;
              timeout = 2;
              weight = 2;
              fall = 3;
              rise = 2;
              user = "root";
            };
          };

        vrrpInstances.mesh_ingress = {
          state = "BACKUP";
          inherit (cfg) interface;
          virtualRouterId = cfg.vrrp.router-id;
          inherit (cfg.vrrp) priority;
          noPreempt = !cfg.vrrp.preempt;

          virtualIps = [
            {
              addr = vip-cidr;
              dev = cfg.interface;
            }
          ];

          trackScripts =
            optional cfg.checks.consul "check-consul"
            ++ optional cfg.checks.traefik "check-traefik"
            ++ cfg.checks.custom;

          extraConfig = ''
            advert_int ${toString cfg.vrrp.advert-interval}

            notify_master "${bash} -c 'echo \"[$(date)] ${hostname} became MASTER for VIP ${cfg.vip.address}\" | ${systemd-cat} -t keepalived -p info'"
            notify_backup "${bash} -c 'echo \"[$(date)] ${hostname} became BACKUP for VIP ${cfg.vip.address}\" | ${systemd-cat} -t keepalived -p info'"
            notify_fault  "${bash} -c 'echo \"[$(date)] ${hostname} entered FAULT state for VIP ${cfg.vip.address}\" | ${systemd-cat} -t keepalived -p err'"
          '';
        };

        extraGlobalDefs = ''
          router_id ${hostname}
          vrrp_version 3
          vrrp_garp_master_delay 1
          vrrp_garp_master_refresh 60
          use_symlink_paths true
        '';
      };

      systemd.services.keepalived = {
        after =
          optional cfg.checks.consul "consul.service" ++ optional cfg.checks.traefik "traefik.service";
        wants =
          optional cfg.checks.consul "consul.service" ++ optional cfg.checks.traefik "traefik.service";
      };
    };
}
