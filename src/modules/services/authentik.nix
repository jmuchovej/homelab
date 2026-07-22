{
  # OIDC discovery URL helper, reachable as `<rbn/authentik/openid-url>`.
  # Usage: <rbn/authentik/openid-url> "homebox" "da"
  rbn.authentik._.openid-url = {
    __functor =
      _self: client-id: datacenter:
      "https://id.${datacenter}.jm0.io/application/o/${client-id}-oauth/.well-known/openid-configuration";
  };
}
