## Service-mesh helpers — consul registration, traefik service builders,
## healthcheck/authentik tag generators. Used by `modules/mesh.nix` (the
## `<rbn/mesh/register>` provider) and the infra services that need custom
## registration (consul, traefik, nomad, openbao, authentik, home-assistant).
{ lib, ... }:
let
  inherit (lib)
    mkDefault
    mkMerge
    optionalAttrs
    mapAttrsToList
    flatten
    mkIf
    ;
  inherit (builtins) isList;
  inherit (lib.strings)
    concatStringsSep
    splitString
    replaceStrings
    removePrefix
    ;
  inherit (builtins) head filter;

  mesh = rec {
    dynamic-http = http: {
      services.traefik.dynamicConfigOptions.http = http;
    };

    # Helper to merge service config into Traefik dynamicConfigOptions.http
    # Usage: services.traefik.dynamicConfigOptions.http = apply-service (mk-traefik-service {...});
    apply-service =
      s:
      mkMerge [
        (optionalAttrs ((s ? pub) ? name) { routers.${s.pub.name} = s.pub.config; })
        (optionalAttrs ((s ? lab) ? name) { routers.${s.lab.name} = s.lab.config; })
        { services.${s.svc.name} = s.svc.config; }
      ];

    # Alternative helper that lets you modify parts before applying
    # Usage: apply-service' (svc: svc // { public.config.rule = "..."; })
    apply-service' = fn: service: apply-service (fn service);

    /**
      Creates a rule for a given subdomain and domain.
      If subdomain is a list, it creates a rule for each subdomain.
      If subdomain is a string, it creates a rule for that subdomain.
      If subdomain is null, it creates a rule for the domain itself.
    */
    mk-rule =
      subdomain: domain:
      let
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
    mk-traefik-service =
      {
        name,
        port,
        hostname,
        datacenter,
        subdomain ? name,
        domain ? "${datacenter}.jm0.io",
        public ? true,
        entry-points ? [ "websecure" ],
        cert-resolver ? "letsencrypt",
        middlewares ? [ ],
        priority ? 10,
        route ? null,
      }:
      let

        pub-rule =
          let
            host-rule = mk-rule subdomain domain;
          in
          if route != null then "(${host-rule}) && PathPrefix(`${route}`)" else host-rule;
        rule-parts = splitString "||" pub-rule;
        no-hosts = map (s: replaceStrings [ "Host(`" "`)" " " ] [ "" "" "" ] s) rule-parts;
        base-url = head no-hosts;

        service-config = {
          loadBalancer.server.port = mkDefault (toString port);
        };
      in
      {
        pub = {
          inherit name;
          config = {
            service = name;
            rule = pub-rule;
            entryPoints = entry-points;
            inherit middlewares;
            tls.certResolver = cert-resolver;
            inherit priority;
          };
        };

        auth =
          if (builtins.elem "authentik@file" middlewares) then
            {
              name = "${name}-auth";
              config = {
                service = "authentik@file";
                rule = "(${pub-rule}) && PathPrefix(`/outpost.goauthentik.io/`)";
                entryPoints = entry-points;
                tls.certResolver = cert-resolver;
                middlewares = filter (mw: mw != "authentik@file") middlewares;
                priority = priority + 5;
              };
            }
          else
            { };

        # Accessor for backend service
        svc = {
          inherit name;
          config = service-config;
        };

        url = {
          ext = base-url;
          int = base-url;
        };

        # Store original parameters for Consul registration
        inherit
          port
          hostname
          datacenter
          subdomain
          domain
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
        datacenter,
        subdomain ? name,
        domain ? "${datacenter}.jm0.io",
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
          datacenter
          subdomain
          domain
          public
          entry-points
          cert-resolver
          ;
        # Reference middleware from file provider when using Consul
        middlewares = middlewares ++ [ "authentik@file" ];
      };

    # Convenience wrapper that restricts access to local networks only
    # Perfect for *arr apps, admin panels, and other internal-only services
    mk-local-only-service =
      {
        name,
        port,
        hostname,
        datacenter,
        subdomain ? name,
        domain ? "${datacenter}.jm0.io",
        public ? true,
        entry-points ? [ "websecure" ],
        cert-resolver ? "letsencrypt",
        middlewares ? [ ],
        restriction ? "local-only", # local-only | admin-only | homelab-only
      }:
      mk-traefik-service {
        inherit
          name
          port
          hostname
          datacenter
          subdomain
          domain
          public
          entry-points
          cert-resolver
          ;
        # Add the IP whitelist middleware based on restriction level
        middlewares = middlewares ++ [ "${restriction}@file" ];
      };

    # Convert a service structure from mk-traefik-service into Consul tags
    # This flattens the router/service configs into the tag format Consul expects
    mk-traefik-tags =
      service:
      let
        inherit (service) pub auth svc;

        # Helper to unwrap mkDefault/mkOverride values
        unwrap-value =
          value:
          if builtins.isAttrs value && value ? _type then
            # This is a wrapped value (mkDefault, mkOverride, etc.)
            if value._type == "override" && value ? content then unwrap-value value.content else value
          else
            value;

        # Helper to convert attrset to tags with prefix
        attrs-to-tags =
          prefix: attrs:
          let
            to-tag =
              name: value:
              let
                inherit (builtins)
                  isAttrs
                  isList
                  genList
                  head
                  elemAt
                  length
                  isBool
                  ;
                unwrapped = unwrap-value value;
              in
              if isAttrs unwrapped && !(unwrapped ? _type) then
                attrs-to-tags "${prefix}.${name}" unwrapped
              else if isList unwrapped then
                # Check if list contains attrsets (like servers list)
                if unwrapped != [ ] && isAttrs (head unwrapped) then
                  # Convert list of attrsets to indexed tags: servers[0].url=...
                  let
                    indexed-tags = genList (i: attrs-to-tags "${prefix}.${name}[${toString i}]" (elemAt unwrapped i)) (
                      length unwrapped
                    );
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
        pub-tags = attrs-to-tags "traefik.http.routers.${pub.name}" pub.config;

        # Generate tags for local router
        auth-tags =
          if auth ? config then attrs-to-tags "traefik.http.routers.${auth.name}" auth.config else [ ];

        # Generate tags for backend service
        svc-tags = attrs-to-tags "traefik.http.services.${svc.name}" svc.config;
      in
      filter (tag: tag != null && tag != "") (
        [ "traefik.enable=true" ] ++ pub-tags ++ auth-tags ++ svc-tags
      );

    mk-authentik =
      service:
      {
        name ? service.svc.name,
        type ? "proxy", # proxy, oauth, ldap
        group ? null, # "Media", "Compute", etc.
        access ? [ ], # ["media", "admins", ...]
        icon ? service.svc.name,
        skip-paths ? null,
        basic-auth ? false,
      }:
      let
        tags = [
          "authentik.name=${name}"
          "authentik.group=${group}"
          "authentik.type=${type}"
          "authentik.url.ext=https://${service.url.ext}"
          "authentik.url.int=https://${service.url.int}"
        ]
        ++ lib.optionals (icon != null) [ "authentik.icon=${icon}" ]
        ++ lib.optionals (access != [ ]) [ "authentik.access=${lib.concatStringsSep "," access}" ]
        ++ lib.optionals (skip-paths != null) [ "authentik.skip-paths=${skip-paths}" ]
        ++ lib.optionals (basic-auth != { } || basic-auth || basic-auth.enabled) [
          "authentik.basic-auth.enabled=${lib.boolToString true}"
          "authentik.basic-auth.username=${basic-auth.username or "username"}"
          "authentik.basic-auth.password=${basic-auth.password or "password"}"
        ];
      in
      filter (tag: tag != null && tag != "") ([ "authentik.enable=true" ] ++ tags);

    # Generate Consul service registration JSON
    # Returns the JSON content for /etc/consul.d/<name>.json
    mk-consul-service =
      {
        name,
        port,
        hostname,
        address ? null,
        tags ? [ ],
        checks ? [ ],
        meta ? { },
      }:
      {
        service = [
          (
            {
              id = "${name}-${hostname}";
              inherit
                name
                port
                tags
                checks
                ;
              meta = meta // {
                node = hostname;
              };
            }
            // (if address != null then { inherit address; } else { })
          )
        ];
      };

    # Helper that registers service in Consul (which then configures Traefik via Consul Catalog provider)
    # Usage: with-consul config (mk-traefik-service {...})
    # When Consul is enabled: Only creates Consul registration (Traefik reads from Consul)
    # When Consul is disabled: Falls back to direct Traefik configuration
    with-consul =
      config: service:
      let
        write-template = service.write-template or false;
        is-public = service.public or false;
        other-tags = service.tags or [ ];

        # Generate base Traefik tags
        base-tags = mk-traefik-tags service;

        # Add "public" tag if service is marked as public
        # This allows Terraform to query Consul and create Cloudflare DNS records
        all-tags = base-tags ++ (if is-public then [ "public" ] else [ ]) ++ other-tags;

        # Always generate the consul service config
        consul-service = mk-consul-service (
          {
            inherit (service) port hostname;
            inherit (service.svc) name;
            checks = service.checks or [ ];
            tags = all-tags;
          }
          // (if service ? address then { inherit (service) address; } else { })
        );

        consul-json = builtins.toJSON consul-service;
        service-file = "consul.d/${service.svc.name}.json";
      in
      mkMerge [
        {
          assertions = [
            {
              assertion =
                (config.rebellion.services.consul.enable or false) || (config.services.consul.enable or false);
              message = ''
                lib.rbn.with-consul requires consul to be enabled.
                Service: ${service.svc.name}

                Enable consul on this host (e.g. via `host.consul.enable = true;`
                or by including the consul service aspect).
              '';
            }
          ];
        }
        (mkIf write-template {
          sops.templates."${service-file}" = {
            content = consul-json;
            restartUnits = [ "consul.service" ];
            owner = "consul";
            group = "consul";
          };
          services.consul.extraConfigFiles = [ config.sops.templates.${service-file}.path ];
        })
        (mkIf (!write-template) {
          environment.etc."${service-file}".text = consul-json;
        })
      ];

    mk-healthcheck =
      service:
      {
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
      }:
      let
        healthcheck-base = {
          inherit
            id
            interval
            timeout
            method
            header
            ;
          http = "${protocol}://${host}:${toString port}/${removePrefix "/" route}";
        };

        healthcheck =
          if method == "POST" then healthcheck-base // { body = builtins.toJSON body; } else healthcheck-base;
      in
      healthcheck;
  };
in
{
  _rbn-lib = mesh;
}
