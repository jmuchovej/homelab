{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.keepalived";
  description = "Keepalived VIP failover";

  options =
    { lib, ... }:
    with lib.types;
    let
      inherit (lib.rebellion) mk mk-bool mk-enable;
    in
    {
      interface = mk str "enp1s0" "Network interface for VIP";

      vip = {
        address = mk str "10.69.1.1" "Virtual IP address";
        prefix = mk int 16 "Network prefix length";
      };

      vrrp = {
        router-id = mk int 51 "VRRP router ID (must be same across all nodes)";
        priority = mk int 100 "VRRP priority (higher = preferred master)";
        preempt = mk-bool false "Whether higher priority node should reclaim VIP";
        advert-interval = mk int 1 "Advertisement interval in seconds";
      };

      checks = {
        consul = mk-enable "Consul Healthcheck" true;
        traefik = mk-enable "Traefik Healthcheck" true;
        custom = mk (listOf str) [ ] "Additional custom health check script names";
      };
    };

  config =
    {
      cfg,
      lib,
      pkgs,
      hostname,
      ...
    }:
    let
      inherit (lib) getExe getExe';

      curl = getExe pkgs.curl;
      bash = getExe pkgs.bash;
      systemd-cat = getExe' pkgs.systemd "systemd-cat";

      vip-cidr = "${cfg.vip.address}/${toString cfg.vip.prefix}";

      inherit (cfg) checks;
      check-traefik = {
        script = "${curl} -sf http://127.0.0.1:8080/ping";
        interval = 2;
        timeout = 2;
        weight = 2;
        fall = 3;
        rise = 2;
        user = "root";
      };
      check-consul = {
        script = "${curl} -sf http://127.0.0.1:8500/v1/status/leader";
        interval = 2;
        timeout = 2;
        weight = 2;
        fall = 3;
        rise = 2;
        user = "root";
      };
    in
    {
      services.keepalived = {
        enable = true;
        openFirewall = true;
        enableScriptSecurity = true;

        vrrpScripts =
          { }
          // lib.optionalAttrs checks.consul.enable { inherit check-consul; }
          // lib.optionalAttrs checks.traefik.enable { inherit check-traefik; };

        vrrpInstances.mesh_ingress = {
          state = "BACKUP"; # All nodes start as backup, VRRP elects master
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
            lib.optional checks.consul.enable "check-consul"
            ++ lib.optional checks.traefik.enable "check-traefik"
            ++ checks.custom;

          extraConfig = ''
            advert_int ${toString cfg.vrrp.advert-interval}

            # Notify scripts for logging
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

      # Ensure keepalived starts after dependent services
      systemd.services.keepalived = {
        after =
          lib.optional cfg.checks.consul.enable "consul.service"
          ++ lib.optional cfg.checks.traefik.enable "traefik.service";
        wants =
          lib.optional checks.consul.enable "consul.service"
          ++ lib.optional checks.traefik.enable "traefik.service";
      };
    };
}
