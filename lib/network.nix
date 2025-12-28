{ inputs }:
let
  inherit (inputs.nixpkgs.lib)
    mkDefault
    mkMerge
    optionalAttrs
    ;

  module = import ./module.nix { inherit inputs; };
  inherit (module) merge-attrs;
in
rec {
  dynamic-http = http: {
    services.traefik.dynamicConfigOptions.http = http;
  };

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

  /**
   * Creates a rule for a given subdomain and domain.
   * If subdomain is a list, it creates a rule for each subdomain.
   * If subdomain is a string, it creates a rule for that subdomain.
   * If subdomain is null, it creates a rule for the domain itself.
   */
  mk-rule = subdomain: domain:
    let
      inherit (builtins) isList;
      inherit (inputs.nixpkgs.lib.strings) concatStringsSep;
      subdomain-ls = if isList subdomain then subdomain else [ subdomain ];
    in
    if (subdomain == null || subdomain == "") then
      "Host(`${domain}`)"
    else
      concatStringsSep " || " (map (s: "Host(`${s}.${domain}`)") subdomain-ls);

  # Build rule for public domain
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
  mk-traefik-service =
    {
      name,
      port,
      hostname,
      subdomain ? name,
      pub-domain ? "jm0.io",
      lab-domain ? "${hostname}.lab",
      public ? true,
      entry-points ? [ "websecure" ],
      cert-resolver ? "letsencrypt",
      middlewares ? [ ],
    }:
    let
      pub-rule = mk-rule subdomain pub-domain;

      # Build rule for local .lab domain
      lab-rule = mk-rule subdomain lab-domain;

      # Build router configs
      router-config = {
        service = name;
        entryPoints = entry-points;
        middlewares = middlewares;
      };

      service-config = {
        loadBalancer.server.port = mkDefault (toString port);
        # loadBalancer.servers = mkDefault [
        #   { url = "http://localhost:${toString port}"; }
        # ];
      };
    in
    # Return a structured result with accessors
    {
      # Accessor for public router (only present if public = true)
      pub =
        if public then
          {
            inherit name;
            config = merge-attrs [router-config {
              rule = mkDefault pub-rule;
              tls.certResolver = cert-resolver;
            }];
          }
        else
          null;

      # Accessor for local router (always present)
      lab = {
        name = "${name}-lab";
        config = merge-attrs [router-config {
          rule = mkDefault lab-rule;
          tls = {};
        }];
      };

      # Accessor for backend service
      svc = {
        inherit name;
        config = service-config;
      };

      # Store original parameters for Consul registration
      inherit
        port
        hostname
        subdomain
        pub-domain
        lab-domain
        public
        middlewares
        ;
    };

  # Convenience wrapper that adds Authentik authentication middleware
  mk-authd-traefik-service =
    {
      name,
      port,
      hostname,
      subdomain ? name,
      pub-domain ? "jm0.io",
      lab-domain ? "${hostname}.lab",
      public ? true,
      entry-points ? [ "websecure" ],
      cert-resolver ? "letsencrypt",
      middlewares ? [ ],
    }:
    mk-traefik-service {
      inherit
        name
        port
        hostname
        subdomain
        pub-domain
        lab-domain
        public
        entry-points
        cert-resolver
        ;
      # Reference middleware from file provider when using Consul
      middlewares = middlewares ++ [ "authentik@file" ];
    };

  # Convert a service structure from mk-service into Consul tags
  # This flattens the router/service configs into the tag format Consul expects
  mk-traefik-tags = service: let
    inherit (service) lab pub svc;
    inherit (inputs.nixpkgs.lib)
      optionals
      filter
      concatStringsSep
      mapAttrsToList
      flatten;

    # Helper to unwrap mkDefault/mkOverride values
    unwrap-value = value:
      if builtins.isAttrs value && value ? _type then
        # This is a wrapped value (mkDefault, mkOverride, etc.)
        if value._type == "override" && value ? content then
          unwrap-value value.content
        else
          value
      else
        value;

    # Helper to convert attrset to tags with prefix
    attrs-to-tags = prefix: attrs:
      let
        to-tag = name: value:
          let
            inherit (builtins) isAttrs isList genList head elemAt length isBool;
            unwrapped = unwrap-value value;
          in
          if isAttrs unwrapped && !(unwrapped ? _type) then
            attrs-to-tags "${prefix}.${name}" unwrapped
          else if isList unwrapped then
            # Check if list contains attrsets (like servers list)
            if unwrapped != [] && isAttrs (head unwrapped) then
              # Convert list of attrsets to indexed tags: servers[0].url=...
              let
                indexed-tags = genList (i:
                  attrs-to-tags "${prefix}.${name}[${toString i}]" (elemAt unwrapped i)
                ) (length unwrapped);
              in
                flatten indexed-tags
            else
              # Simple list - join with commas
              "${prefix}.${name}=${concatStringsSep "," (map toString unwrapped)}"
          else if isBool unwrapped then
            "${prefix}.${name}=${if unwrapped then "true" else "false"}"
          else
            "${prefix}.${name}=${toString unwrapped}";
      in
        flatten (mapAttrsToList to-tag attrs);

    # Generate tags for public router (if present)
    pub-tags = optionals (pub != null) (
      attrs-to-tags "traefik.http.routers.${pub.name}" pub.config
    );

    # Generate tags for local router
    lab-tags = attrs-to-tags "traefik.http.routers.${lab.name}" lab.config;

    # Generate tags for backend service
    svc-tags = attrs-to-tags "traefik.http.services.${svc.name}" svc.config;
  in
    filter (tag: tag != null && tag != "") (
      [ "traefik.enable=true" ]
      ++ pub-tags
      ++ lab-tags
      ++ svc-tags
    );

  # Generate Consul service registration JSON
  # Returns the JSON content for /etc/consul.d/<name>.json
  mk-consul-service =
    {
      name,
      port,
      hostname,
      tags ? [ ],
      checks ? [ ],
      meta ? { },
    }:
    {
      service = [
        {
          # id = "${name}-${hostname}";
          id = name;
          inherit name port tags checks;
          # Omit the address field so Consul uses the node's registered address.
          #   This ensures services get the actual IP from the agent's interface
          #   configuration.
          meta = meta // {
            node = hostname;
          };
        }
      ];
    };

  # Helper that registers service in Consul (which then configures Traefik via Consul Catalog provider)
  # Usage: with-consul config (mk-service {...})
  # When Consul is enabled: Only creates Consul registration (Traefik reads from Consul)
  # When Consul is disabled: Falls back to direct Traefik configuration
  #
  # For services with secrets in healthchecks, pass the template name:
  #   with-consul config (service // {
  #     checks = [ healthcheck ];
  #     template = "consul-hass";
  #   })
  # This will automatically create `sops.templates.<template>.content` with the JSON.
  with-consul =
    config: service:
    let
      inherit (inputs.nixpkgs.lib) mkMerge mkIf;
      has-template = service ? template;

      # Always generate the consul service config
      consul-service = mk-consul-service {
        inherit (service) port hostname;
        name = service.svc.name;
        checks = service.checks or [ ];
        tags = mk-traefik-tags service;
      };

      consul-json = builtins.toJSON consul-service;
    in
    mkMerge [
      # Assert that mesh.enable exists and is explicitly set (not undefined)
      {
        assertions = [
          {
            assertion = config.rebellion.services.mesh ? enable;
            message = ''
              lib.rebellion.network.with-consul requires rebellion.services.mesh.enable to be explicitly set.
              Service: ${service.svc.name}

              Please add to your configuration:
                rebellion.services.mesh.enable = true;  # or false for fallback mode
            '';
          }
        ];
      }
      # If using a sops template, create the template and use it as source
      (mkIf has-template {
        sops.templates.${service.template} = {
          content = consul-json;
          owner = "consul";
          restartUnits = [ "consul.service" ];
          path = "/etc/consul.d/${service.svc.name}.json";
        };
        # environment.etc."consul.d/${service.svc.name}.json".source =
          # config.sops.templates.${service.template}.path;
      })
      # Otherwise write JSON directly
      (mkIf (!has-template) {
        environment.etc."consul.d/${service.svc.name}.json".text = consul-json;
      })
    ];

  mk-healthcheck = service: {
    id ? service.svc.name,
    protocol ? "http",
    host ? "localhost",
    port ? service.port,
    route,
    interval ? "10s",
    timeout ? "2s",
    header ? { },
    body ? { },
    method ? "GET",
  }: let
    inherit (inputs.nixpkgs.lib.strings) removePrefix;

    healthcheck-base = {
      inherit id interval timeout method header;
      http = "${protocol}://${host}:${toString port}/${removePrefix "/" route}";
    };

    healthcheck = if method == "POST" then
        healthcheck-base // { body = builtins.toJSON body; }
      else
        healthcheck-base;
  in healthcheck;
}
