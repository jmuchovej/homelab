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
      # Find "base" config (if it exists -- `null` host)
      base-configs = filterAttrs (_name: config: config.hostname == null) system-configs;
      # Find a host-specific config
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
    # No host-specific configs. Just use the base configs directly.
    if host-configs == { } then
      mapAttrs (
        _name: base-config:
        base-config
        // {
          modules = [ base-config.path ];
        }
      ) base-configs
    else
      # Merge host configs with their corresponding base (if exists).
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
          ++ (ext-lib.import-modules-recursive ../../modules/home { });

          users = mapAttrs' (_name: config: {
            name = config.username;
            value = {
              imports = config.modules;
              home = {
                inherit (config) username;
                homeDirectory =
                  let
                    # username = builtins.trace "DEBUG[lib/system/common.nix]: username=${toString config.username}" config.username;
                    username = config.username;
                    home-directory = if isNixOS then "/home/${username}" else "/Users/${username}";
                    # hd = builtins.trace "DEBUG[lib/system/common.nix]: home-directory=${toString home-directory}" home-directory;
                    hd = inputs.lib.mkDefault home-directory;
                  in
                  inputs.nixpkgs.lib.mkDefault (/. + hd);
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
      system,
    }:
    let
      inherit (inputs.nixpkgs.lib)
        splitString
        concatStringsSep
        filter
        hasPrefix
        ;
      inherit (builtins)
        head
        tail
        length
        attrNames
        ;

      # Parse hostname into datacenter and nodename
      # Example: "da-vcx-1" -> { datacenter = "da"; nodename = "vcx-1"; }
      parsed =
        let
          parts = splitString "-" hostname;
        in
        if length parts >= 2 then
          {
            datacenter = head parts;
            nodename = concatStringsSep "-" (tail parts);
          }
        else
          {
            datacenter = null;
            nodename = hostname;
          };

      # Gather all systems in the same datacenter
      # Returns list of hostnames like ["da-vcx-1", "da-vcx-2", "da-vcx-3"]
      peers =
        let
          flake = inputs.self;
          allSystems = if flake ? nixosConfigurations then attrNames flake.nixosConfigurations else [ ];
          dcPrefix = "${parsed.datacenter}-";
        in
        if parsed.datacenter != null then filter (h: hasPrefix dcPrefix h) allSystems else [ ];
    in
    {
      inherit
        inputs
        hostname
        username
        system
        peers
        ;
      inherit (inputs) self;
      inherit (parsed) datacenter nodename;
      lib = ext-lib;
      flake-parts-lib = inputs.flake-parts.lib;
      format = "system";
      host = hostname;
    };
}
