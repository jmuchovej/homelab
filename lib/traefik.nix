{ inputs }:
let
  inherit (inputs.lib) mkDefault mkMerge concatMapStringsSep;
in
rec {
  # Create a standardized Traefik service configuration
  # Returns router and service config that should be assigned to dynamicConfigOptions.http
  # Usage in modules: services.traefik.dynamicConfigOptions.http = lib.rebellion.traefik.mk-service { ... };
  mk-service =
    {
      name,
      port,
      subdomain ? name,
      domain ? "jm0.io",
      entry-points ? [ "websecure" ],
      cert-resolver ? "letsencrypt",
      middlewares ? [ ],
      extra-router-config ? { },
      extra-service-config ? { },
    }:
    let
      rules =
        if builtins.isList subdomain then
          concatMapStringsSep " || " (sub: "`${sub}.${domain}`") subdomain
        else if builtins.isString subdomain then
          "${subdomain}.${domain}"
        else
          domain;
    in
    {
      routers.${name} = mkMerge [
        {
          rule = mkDefault "Host(`${rules}`)";
          service = name;
          entryPoints = entry-points;
          tls.certResolver = cert-resolver;
          middlewares = middlewares;
        }
        extra-router-config
      ];

      services.${name} = mkMerge [
        {
          loadBalancer.servers = mkDefault [
            {
              url = "http://localhost:${toString port}";
            }
          ];
        }
        extra-service-config
      ];
    };

  mk-authd-service =
    {
      name,
      port,
      subdomain ? name,
      domain ? "jm0.io",
      entry-points ? [ "websecure" ],
      cert-resolver ? "letsencrypt",
      middlewares ? [ ],
      extra-router-config ? { },
      extra-service-config ? { },
    }:
    mk-service {
      inherit
        name
        port
        subdomain
        domain
        entry-points
        cert-resolver
        extra-router-config
        extra-service-config
        ;
      middlewares = middlewares ++ [ "authentik" ];
    };
}
