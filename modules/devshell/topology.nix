{ self, lib, ... }: {
  perSystem = { pkgs, ... }: {
    # The cross-key rules `topology.schema.json` cannot express.
    checks.topology =
      let
        inherit (lib)
          attrNames
          concatStringsSep
          filterAttrs
          length
          mapAttrs
          mapAttrsToList
          pipe
          ;
        relays = (lib.importTOML (self + "/topology.toml")).network;

        site-of = name: lib.head (lib.splitString "-" name);
        downstream-of =
          target:
          pipe relays [
            (filterAttrs (_: relay: (relay.uplink or null) == target))
            attrNames
          ];
        routers-by-site = pipe relays [
          (filterAttrs (_: relay: relay.role == "router"))
          attrNames
          (lib.groupBy site-of)
        ];

        dangling = pipe relays [
          (filterAttrs (_: relay: relay ? uplink && !(relays ? ${relay.uplink})))
          (mapAttrsToList (name: relay: "${name}: uplink `${relay.uplink}` is not a relay in `network`"))
        ];

        short-trunks = pipe relays [
          (mapAttrs (
            name: relay: {
              downstream = downstream-of name;
              trunks = relay.trunks or [ ];
            }
          ))
          (filterAttrs (_: relay: length relay.downstream > length relay.trunks))
          (mapAttrsToList (
            name: relay:
            "${name}: ${toString (length relay.downstream)} relay(s) uplink here (${concatStringsSep ", " relay.downstream}) but it has ${toString (length relay.trunks)} trunk(s)"
          ))
        ];

        extra-routers = pipe routers-by-site [
          (filterAttrs (_: routers: length routers > 1))
          (mapAttrsToList (
            site: routers: "${site}: expected one router, found ${concatStringsSep ", " routers}"
          ))
        ];

        errors = dangling ++ short-trunks ++ extra-routers;
      in
      pkgs.runCommand "topology"
        {
          report = lib.concatMapStrings (error: "FAIL ${error}\n") errors;
          passAsFile = [ "report" ];
        }
        ''
          if [ -s "$reportPath" ]; then
            cat "$reportPath"
            exit 1
          fi
          touch $out
        '';
  };
}
