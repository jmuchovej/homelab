{ inputs }:
let
  inherit (inputs.nixpkgs.lib) filterAttrs mapAttrs' mapAttrs;
  inherit (builtins) attrValues;
in
{
  mk-ext-lib = flake: nixpkgs: nixpkgs.lib.extend flake.lib.overlay;

  mk-nixpkgs-config = flake: {
    overlays = attrValues flake.overlays ++ (flake.rebellion.overlays or [ ]);
    config = {
      allowAliases = false;
      allowUnfree = true;
      permittedInsecurePackages = [
      ];
    };
  };

  gather-homes =
    {
      flake,
      system,
      hostname,
    }:
    let
      inherit (flake.lib.file) parse-home-configurations;
      home-paths = ../../homes;
      all-homes = parse-home-configurations home-paths;

      # Match the sytem architecture
      system-configs = filterAttrs (_name: config: config.system == system) all-homes;
      # Filters for matching username (with `null` host)
      base-configs = filterAttrs (_name: config: config.hostname == null) system-configs;
      # Filters for matching hostname
      host-configs = filterAttrs (_name: config: config.hostname == hostname) system-configs;

      merge-configs =
        user-at-host: host-config:
        let
          base-config = base-configs.${host-config.username};
          base-module = if base-config != null then [ base-config.path ] else [ ];
        in
        host-config
        // {
          modules = base-module ++ [ host-config.path ];
        };
    in
    mapAttrs merge-configs host-configs;

  mk-hm-config =
    {
      ext-lib,
      inputs,
      system,
      matching-homes,
      isNixOS ? true,
      flake,
    }:
    if matching-homes == { } then
      { }
    else
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {
            inherit inputs system;
            inherit (inputs) self;
            lib = ext-lib;
            flake-parts-lib = inputs.flake-parts.lib;
          };
          sharedModules = [
            { _module.args.lib = ext-lib; }
          ]
          ++ flake.rebellion.modules.homes
          ++ (ext-lib.import-modules-recursive ../../modules/home);

          users = mapAttrs' (_name: config: {
            name = config.username;
            value = {
              imports = config.modules;
              home = {
                inherit (config) username;
                homeDirectory = inputs.nixpkgs.lib.mkDefault (
                  if isNixOS then "/home/${config.username}" else "/Users/${config.username}"
                );
              };
            }
            // (if isNixOS then { _module.args.username = config.username; } else { });
          }) matching-homes;
        };
      };

  mk-special-args =
    {
      inputs,
      hostname,
      username,
      ext-lib,
    }:
    {
      inherit inputs hostname username;
      inherit (inputs) self;
      lib = ext-lib;
      flake-parts-lib = inputs.flake-parts.lib;
      format = "system";
      host = hostname;
    };
}
