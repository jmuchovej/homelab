{
  config,
  lib,
  pkgs,
  system,
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
  inherit (pkgs.stdenv) isLinux;
  inherit (lib.rebellion) mkopt enabled disabled;

  cfg = config.rebellion.nix;
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
  options.rebellion.system.nix = with types; {
    enable = mkEnableOption "manage nix configuration" // {
      default = true;
    };
    package = mkopt package pkgs.nixVersions.latest "Which nix package to use.";
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
      nixd
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
          config.rebellion.user.name
        ];
      in
      {
        inherit (cfg) package;
        enable = cfg.enable;

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

        optimise.automatic = config.nix.enable;

        gc = {
          automatic = config.nix.enable;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };

        # flake-utils-plus
        #! FIXME: can't be use on macOS because `darwin` conflicts with `nix-darwin`'s registrations?
        #! It seems like assigning the `darwin` input to `nix-darwin` would fix this; but snowfall requires `darwin` be the input name.
        # https://github.com/snowfallorg/lib/issues/75
        # https://github.com/LnL7/nix-darwin/pull/732
        # https://github.com/LnL7/nix-darwin/issues/1082
        # generateRegistryFromInputs  = true;
        # generateNixPathFromInputs = true;
        # linkInputs = true;
      };
  };

  nixpkgs.hostPlatform = mkDefault system;
}
