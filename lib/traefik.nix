{ inputs }:
let
  inherit (inputs.nixpkgs.lib)
    mkDefault
    mkMerge
    concatStringsSep
    optionalAttrs
    mkIf
    ;

  consul = import ./consul.nix { inherit inputs; };
in
rec {
  dynamic-http = http: {
    services.traefik.dynamicConfigOptions.http = http;
  };

  # Helper that registers service in Consul (which then configures Traefik via Consul Catalog provider)
  # Usage: with-consul config (mk-service {...})
  # When Consul is enabled: Only creates Consul registration (Traefik reads from Consul)
  # When Consul is disabled: Falls back to direct Traefik configuration
  with-consul =
    config: svc:
    let
      consul-enabled = config.services.consul.enable or false;
    in
    mkMerge [
      # If Consul is enabled, ONLY register in Consul (Traefik will discover via Catalog)
      # If Consul is disabled, fall back to direct Traefik config
      (
        if consul-enabled then
          {
            environment.etc = consul.mk-consul-config {
              name = svc.svc.name;
              port = svc.port;
              hostname = svc.hostname;
              subdomain = svc.subdomain;
              middlewares = svc.middlewares or [ ];
              checks = svc.checks or null;
            };
          }
        else
          (apply-service svc)
      )
    ];

  # Helper to merge service config into Traefik dynamicConfigOptions.http
  # Usage: services.traefik.dynamicConfigOptions.http = apply-service (mk-service {...});
  apply-service =
    svc:
    mkMerge [
      (optionalAttrs (svc ? pub) { routers.${svc.pub.name} = svc.pub.config; })
      (optionalAttrs (svc ? lab) { routers.${svc.lab.name} = svc.lab.config; })
      { services.${svc.svc.name} = svc.svc.config; }
    ];

  # Alternative helper that lets you modify parts before applying
  # Usage: apply-service' (svc: svc // { public.config.rule = "..."; })
  apply-service' = fn: svc: apply-service (fn svc);

  # Create a standardized Traefik service configuration
  # Returns router and service config that should be assigned to dynamicConfigOptions.http
  #
  # Creates routers based on the 'public' parameter:
  # - public = true (default): Creates BOTH public and local routers
  #   - Public router: <subdomain>.<domain> (e.g., plex.da.jm0.io) with Let's Encrypt
  #   - Local router: <subdomain>.<hostname>.lab (e.g., plex.da-vcx-1.lab) with self-signed cert
  # - public = false: Creates ONLY local router (e.g., radarr.da-vcx-1.lab)
  #
  # Both routers (when present) point to the same backend service.
  #
  # Usage: services.traefik.dynamicConfigOptions.http = lib.rebellion.traefik.mk-service {
  #   name = "plex";
  #   port = 32400;
  #   public = true;  # Optional, defaults to true
  # };
  mk-service =
    {
      name,
      port,
      hostname,
      subdomain ? name,
      domain ? "jm0.io",
      public ? true,
      entry-points ? [ "websecure" ],
      cert-resolver ? "letsencrypt",
      middlewares ? [ ],
      checks ? null,
    }:
    let
      # Build rule for public domain
      pub-rule =
        if builtins.isList subdomain then
          "HostRegexp(`(" + (concatStringsSep "|" subdomain) + ")\.${domain}$`)"
        else if builtins.isString subdomain then
          "Host(`${subdomain}.${domain}`)"
        else
          "Host(`${domain}`)";

      # Build rule for local .lab domain
      lab-rule =
        if builtins.isList subdomain then
          "HostRegexp(`(" + (concatStringsSep "\|" subdomain) + ")\.${hostname}.lab$`)"
        else if builtins.isString subdomain then
          "Host(`${subdomain}.${hostname}.lab`)"
        else
          "Host(`${hostname}.lab`)";

      # Build router configs
      pub-router-config = {
        rule = mkDefault pub-rule;
        service = name;
        entryPoints = entry-points;
        tls.certResolver = cert-resolver;
        middlewares = middlewares;
      };

      lab-router-config = {
        rule = mkDefault lab-rule;
        service = name;
        entryPoints = entry-points;
        tls = { };
        middlewares = middlewares;
      };

      service-config = {
        loadBalancer.servers = mkDefault [
          { url = "http://localhost:${toString port}"; }
        ];
      };
    in
    # Return a structured result with accessors
    {
      # Accessor for public router (only present if public = true)
      pub =
        if public then
          {
            name = name;
            config = pub-router-config;
          }
        else
          null;

      # Accessor for local router (always present)
      lab = {
        name = "${name}-lab";
        config = lab-router-config;
      };

      # Accessor for backend service
      svc = {
        name = name;
        config = service-config;
      };

      # Store original parameters for Consul registration
      inherit
        port
        hostname
        subdomain
        domain
        public
        middlewares
        checks
        ;
    };

  # Convenience wrapper that adds Authentik authentication middleware
  mk-authd-service =
    {
      name,
      port,
      hostname,
      subdomain ? name,
      domain ? "jm0.io",
      public ? true,
      entry-points ? [ "websecure" ],
      cert-resolver ? "letsencrypt",
      middlewares ? [ ],
      checks ? null,
    }:
    mk-service {
      inherit
        name
        port
        hostname
        subdomain
        domain
        public
        entry-points
        cert-resolver
        checks
        ;
      middlewares = middlewares ++ [ "authentik" ];
    };
}
