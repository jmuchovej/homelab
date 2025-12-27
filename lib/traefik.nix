{ inputs }:
let
  inherit (inputs.nixpkgs.lib)
    mkDefault
    mkMerge
    mkIf
    concatStringsSep
    optionalAttrs
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
    config: service:
    mkMerge [
      # If Consul is enabled, ONLY register in Consul (Traefik will discover via Catalog)
      # If Consul is disabled, fall back to direct Traefik config
      (mkIf config.rebellion.services.mesh.enable {
        environment.etc = consul.mk-consul-config {
          inherit (service) port hostname;
          name = service.svc.name;
          checks = service.checks or null;
          tags = mk-tags service;
        };
      })
      (mkIf (!config.rebellion.services.mesh.enable) (dynamic-http (apply-service service)))
    ];

  # Helper to merge service config into Traefik dynamicConfigOptions.http
  # Usage: services.traefik.dynamicConfigOptions.http = apply-service (mk-service {...});
  apply-service =
    s:
    mkMerge [
      (optionalAttrs (s ? pub ? name) { routers.${s.pub.name} = s.pub.config; })
      (optionalAttrs (s ? lab ? name) { routers.${s.lab.name} = s.lab.config; })
      { services.${s.svc.name} = s.svc.config; }
    ];

  # Alternative helper that lets you modify parts before applying
  # Usage: apply-service' (svc: svc // { public.config.rule = "..."; })
  apply-service' = fn: service: apply-service (fn service);

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

  # Convert a service structure from mk-service into Consul tags
  # This flattens the router/service configs into the tag format Consul expects
  mk-tags = service: let
    inherit (inputs.nixpkgs.lib)
      optionals
      filter
      concatStringsSep
      mapAttrsToList
      flatten;

    # Helper to convert attrset to tags with prefix
    attrs-to-tags = prefix: attrs:
      let
        to-tag = name: value:
          if builtins.isAttrs value then
            attrs-to-tags "${prefix}.${name}" value
          else if builtins.isList value then
            "${prefix}.${name}=${concatStringsSep "," value}"
          else if builtins.isBool value then
            "${prefix}.${name}=${if value then "true" else "false"}"
          else
            "${prefix}.${name}=${toString value}";
      in
        flatten (mapAttrsToList to-tag attrs);

    # Generate tags for public router (if present)
    pub-tags = optionals (service.pub != null) (
      attrs-to-tags "traefik.http.routers.${service.pub.name}" service.pub.config
    );

    # Generate tags for local router
    lab-tags = attrs-to-tags "traefik.http.routers.${service.lab.name}" service.lab.config;

    # Generate tags for backend service
    svc-tags = attrs-to-tags "traefik.http.services.${service.svc.name}" service.svc.config;

  in
    filter (tag: tag != null && tag != "") (
      [ "traefik.enable=true" ]
      ++ pub-tags
      ++ lab-tags
      ++ svc-tags
    );
}
