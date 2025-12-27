{ inputs }:
rec {
  # Generate Consul service registration JSON
  # Returns the JSON content for /etc/consul.d/<name>.json
  mk-service-registration =
    {
      name,
      port,
      hostname,
      tags ? [ ],
      checks ? null,
      meta ? { },
    }:
    let
      # Default health check if none provided
      default-check = {
        http = "http://localhost:${toString port}";
        interval = "10s";
        timeout = "2s";
      };
    in
    {
      service = {
        id = "${name}-${hostname}";
        inherit name port tags;
        address = hostname;
        checks = if checks != null then checks else [ default-check ];
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
            tags
            checks
            meta
            ;
        });
      };
    };
}
