{ inputs }:
rec {
  # Generate Consul service registration JSON
  # Returns the JSON content for /etc/consul.d/<name>.json
  mk-service-registration =
    {
      name,
      port,
      hostname,
      subdomain ? name,
      middlewares ? [ ],
      tags ? [ ],
      checks ? null,
      meta ? { },
    }:
    let
      inherit (inputs.nixpkgs.lib) concatStringsSep;

      # Default health check if none provided
      default-check = {
        http = "http://localhost:${toString port}";
        interval = "10s";
        timeout = "2s";
      };

      service-checks = if checks != null then checks else [ default-check ];

      # Generate Traefik tags for Consul Catalog provider
      traefik-tags =
        let
          subdomains = if builtins.isList subdomain then subdomain else [ subdomain ];
          # Create tags for local .lab domain routing
          subdomain-tags = map (
            sub: "traefik.http.routers.${name}.rule=Host(`${sub}.${hostname}.lab`)"
          ) subdomains;
          # Add middleware tags if any
          middleware-tags =
            if middlewares != [ ] then
              [ "traefik.http.routers.${name}.middlewares=${concatStringsSep "," middlewares}" ]
            else
              [ ];
        in
        [
          "traefik.enable=true"
          "traefik.http.services.${name}.loadbalancer.server.port=${toString port}"
        ]
        ++ subdomain-tags
        ++ middleware-tags;
    in
    {
      service = {
        id = "${name}-${hostname}";
        inherit name port;
        address = hostname;
        tags = traefik-tags ++ tags;
        checks = service-checks;
        meta = meta // {
          node = hostname;
        };
      };
    };

  # Helper to create the /etc/consul.d/<name>.json file configuration
  mk-consul-config =
    {
      name,
      port,
      hostname,
      subdomain ? name,
      middlewares ? [ ],
      tags ? [ ],
      checks ? null,
      meta ? { },
    }:
    {
      "consul.d/${name}.json" = {
        text = builtins.toJSON (mk-service-registration {
          inherit
            name
            port
            hostname
            subdomain
            middlewares
            tags
            checks
            meta
            ;
        });
      };
    };
}
