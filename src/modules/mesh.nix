_: {
  # Factory provider: creates a consul+traefik mesh registration aspect.
  # Uses __functor pattern (like den's unfree battery).
  #
  # Usage in service aspect includes:
  #   includes = [
  #     (<rbn/mesh/register> {
  #       name = "chroma";
  #       port = 24762;
  #       healthcheck = "/api/v1/heartbeat";
  #     })
  #   ];
  rbn.mesh.provides.register = {
    __functor =
      _self:
      {
        name,
        port,
        healthcheck ? null,
        healthcheck-header ? { },
        healthchecks ? [ ],
        subdomain ? null,
        domain ? null,
        # When `true`, the service is scoped to a single node — the default
        # domain becomes `${hostname}.jm0.io` instead of `${datacenter}.jm0.io`.
        # Use for per-node services (syncthing, node-local admin UIs) that
        # MUST NOT share a hostname with the same service on another node.
        # Has no effect if `domain` is set explicitly.
        node-scoped ? false,
        public ? true,
        authed ? false,
        authentik ? null,
        route ? null,
        priority ? 10,
        middlewares ? [ ],
        address ? null,
        write-template ? false,
        extra-tags ? [ ],
      }:
      { class, ... }:
      if class != "nixos" then
        { }
      else
        {
          nixos =
            {
              host,
              config,
              lib,
              ...
            }:
            let
              inherit (lib.rbn)
                mk-traefik-service
                mk-authd-traefik-service
                mk-healthcheck
                mk-authentik
                with-consul
                ;

              inherit (host) hostname datacenter;
              mk-svc = if authed then mk-authd-traefik-service else mk-traefik-service;

              # Explicit `domain` always wins. Otherwise: per-node services
              # derive from hostname; everything else falls through to
              # `mk-traefik-service`'s default of `${datacenter}.jm0.io`.
              effective-domain =
                if domain != null then
                  domain
                else if node-scoped then
                  "${hostname}.jm0.io"
                else
                  null;

              base-args = {
                inherit
                  hostname
                  datacenter
                  name
                  port
                  public
                  middlewares
                  ;
              }
              // lib.optionalAttrs (subdomain != null) { inherit subdomain; };

              service = mk-svc (
                base-args
                // lib.optionalAttrs (!authed) { inherit priority; }
                // lib.optionalAttrs (effective-domain != null) { domain = effective-domain; }
                // lib.optionalAttrs (!authed && route != null) { inherit route; }
              );

              checks =
                if builtins.isFunction healthchecks then
                  healthchecks { inherit config service mk-healthcheck; }
                else if healthchecks != [ ] then
                  healthchecks
                else if healthcheck != null then
                  [
                    (mk-healthcheck service {
                      route = healthcheck;
                      header = healthcheck-header;
                    })
                  ]
                else
                  [ ];

              tags = (if authentik != null then mk-authentik service authentik else [ ]) ++ extra-tags;
            in
            with-consul config (
              service
              // {
                inherit checks tags;
              }
              // lib.optionalAttrs (address != null) { inherit address; }
              // lib.optionalAttrs write-template { inherit write-template; }
            );
        };
  };
}
