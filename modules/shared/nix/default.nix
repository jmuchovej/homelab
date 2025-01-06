{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib)
    mkIf
    mkDefault
    mkEnableOption
    mkOption
    mkPackageOption
    types
    ;
  inherit (lib.${namespace}) enabled disabled;

  cfg = config.${namespace}.nix;
in
# region Nix Registry
# linux-pkgs  = inputs.nixpkgs;
# darwin-pkgs = inputs.nixpkgs-unstable;
# remap-nixpkgs = (reg: reg //
#   { nixpkgs.flake = if isLinux then linux-pkgs else darwin-pkgs; }
# );
# drop-unstable-from-darwin = (reg:
#   if isDarwin then removeAttrs reg ["nixpkgs-unstable"] else reg
# );
# mappedRegistry = pipe inputs [
#   (filterAttrs (_: isType "flake"))
#   (mapAttrs (_: flake: { inherit flake; }))
#   remap-nixpkgs
#   drop-unstable-from-darwin
# ];
# endregion
# TODO figure out remote building
{
  options.${namespace}.nix = with types; {
    enable = mkEnableOption "manage nix configuration" // {
      default = true;
    };
    package = mkPackageOption pkgs "nixVersions" {
      default = [
        "nixVersions"
        "latest"
      ];
    };
    extra-users = mkOption {
      type = listOf str;
      default = [ ];
      description = "Extra users to trust";
    };
  };

  config = mkIf cfg.enable {
    # faster rebuilding
    documentation = {
      doc = disabled;
      info = disabled;
      man = mkDefault enabled;
    };

    environment.systemPackages = with pkgs; [
      nil
      nixfmt-rfc-style
      nix-index
      nix-prefetch-git
      cachix
      deploy-rs
    ];

    nix =
      let
        users = [
          "root"
          "@wheel"
          "nix-builder"
          config.${namespace}.user.name
        ];
      in
      {
        inherit (cfg) package;

        settings = {
          trusted-users = users ++ cfg.extra-users;
          allowed-users = users;
          use-xdg-base-directories = true;
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          warn-dirty = false;
          system-features = [
            "kvm"
            "big-parallel"
            "nixos-test"
          ];
        };

        optimise.automatic = mkDefault true;

        gc = {
          automatic = true;
          options = "--delete-older-than 7d";
        };

        # flake-utils-plus
        #! FIXME: can't be use on macOS because `darwin` conflicts with `nix-darwin`'s registrations?
        #! It seems like assigning the `darwin` input to `nix-darwin` would fix this; but snowfall requires `darwin` be the input name.
        # https://github.com/snowfallorg/lib/issues/75
        # https://github.com/LnL7/nix-darwin/pull/732
        # https://github.com/LnL7/nix-darwin/issues/1082
        # generateRegistryFromInputs  = true;
        generateNixPathFromInputs = true;
        linkInputs = true;
      };
  };
}
