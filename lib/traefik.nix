{ inputs }:
let
  inherit (inputs.nixpkgs.lib) mkDefault mkMerge concatMapStringsSep;
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
      rule =
        if builtins.isList subdomain then
          "Host(" + (concatMapStringsSep " || " (sub: "`${sub}.${domain}`") subdomain) + ")"
        else if builtins.isString subdomain then
          "Host(`${subdomain}.${domain}`)"
        else
          "Host(`${domain}`)";
    in
    {
      routers.${name} = mkMerge [
        {
          rule = mkDefault rule;
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
