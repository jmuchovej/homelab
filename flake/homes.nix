{
  inputs,
  self,
  lib,
  ...
}:
let
  inherit (lib)
    mapAttrs'
    filterAttrs
    foldl'
    attrValues
    ;
  inherit (self.lib.file) parse-home-configurations;

  homes-path = ../homes;
  hm-configs = parse-home-configurations homes-path;
  base-homes = filterAttrs (_name: config: config.hostname == null) hm-configs;
  host-homes = filterAttrs (_name: config: config.hostname != null) hm-configs;

  generate-home-configuration =
    _base-name: base-config:
    let
      matching-hosts = filterAttrs (_name: config: config.hostname == base-config.hostname) host-homes;

      host-configs = mapAttrs' (_name: host-config: {
        name = host-config.user-dir; # e.g., "john@da-n1x"
        value = self.lib.system.homes {
          inherit (host-config)
            inputs
            system
            username
            hostname
            ;
          # Base modules first, then host-specific (host overrides base)
          modules = [
            base-config.path
            host-config.path
          ];
        };
      }) matching-hosts;

      base-configs =
        if matching-hosts == { } then
          {
            ${base-config.user-dir} = {
              name = base-config.user-dir;
              value = self.lib.system.homes {
                inherit (base-config)
                  inputs
                  system
                  username
                  hostname
                  ;
                # Base modules first, then host-specific (host overrides base)
                modules = [ base-config.path ];
              };
            };
          }
        else
          { };
    in
    base-configs // host-configs;
in
{
  imports = [ inputs.home-manager.flakeModules.home-manager ];

  flake = {
    homeModules = {
      default = ../modules/home;
    };

    # Dynamically generated home configurations
    homeConfigurations = foldl' (
      acc: base: acc // (generate-home-configuration base.user-dir base)
    ) { } (attrValues base-homes);
  };
}
