{ inputs }:
let
  inherit (inputs.nixpkgs.lib)
    mkDefault
    mkMerge
    concatStringsSep
    ;
in
rec {
  # Create a standardized Traefik service configuration
  # Returns router and service config that should be assigned to dynamicConfigOptions.http
  #
  # Automatically creates TWO routers for each service:
  # 1. Public router: <subdomain>.<domain> (e.g., plex.da.jm0.io)
  # 2. Local router: <subdomain>.<hostname>.lab (e.g., plex.da-vcx-1.lab)
  #
  # Both routers point to the same backend service.
  #
  # Usage: services.traefik.dynamicConfigOptions.http = lib.rebellion.traefik.mk-service {
  #   name = "plex";
  #   port = 32400;
  # };
  mk-service =
    {
      name,
      port,
      hostname,
      subdomain ? name,
      domain ? "jm0.io",
      entry-points ? [ "websecure" ],
      cert-resolver ? "letsencrypt",
      middlewares ? [ ],
      extra-router-config ? { },
      extra-service-config ? { },
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
    in
    {
      # Public router (uses Let's Encrypt)
      routers.${name} = mkMerge [
        {
          rule = mkDefault pub-rule;
          service = name;
          entryPoints = entry-points;
          tls.certResolver = cert-resolver;
          middlewares = middlewares;
        }
        extra-router-config
      ];

      # Local router (uses file-based self-signed cert)
      routers."${name}-local" = mkMerge [
        {
          rule = mkDefault lab-rule;
          service = name; # Points to same backend service
          entryPoints = entry-points;
          tls = { }; # Certificate provided via file provider in traefik.nix
          middlewares = middlewares;
        }
      ];

      # Backend service (shared by both routers)
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

  # Convenience wrapper that adds Authentik authentication middleware
  mk-authd-service =
    {
      name,
      port,
      hostname,
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
        hostname
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
