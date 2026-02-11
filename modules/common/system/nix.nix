# Imported by platform-specific system/nix.nix modules.
# TODO figure out remote building
{
  config,
  lib,
  pkgs,
  self,
  inputs,
  system,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkIf
    mkOption
    pipe
    filterAttrs
    mapAttrs
    isType
    types
    ;
  inherit (lib.rebellion) mkopt enabled disabled;
  inherit (pkgs.stdenv) isLinux isDarwin;

  cfg = config.rebellion.system.nix;

  # region Nix Registry
  linux-pkgs = inputs.nixpkgs;
  macos-pkgs = inputs.nixpkgs-unstable;
  remap-nixpkgs =
    reg:
    reg
    // {
      nixpkgs.flake = if isLinux then linux-pkgs else macos-pkgs;
    };
  drop-unstable-macos = reg: if isDarwin then removeAttrs reg [ "nixpkgs-unstable" ] else reg;
  mappedRegistry = pipe inputs [
    (filterAttrs (_: isType "flake"))
    (mapAttrs (_: flake: { inherit flake; }))
    remap-nixpkgs
    drop-unstable-macos
  ];
  # endregion
in
{
  options.rebellion.system.nix = {
    package = mkopt types.package pkgs.lixPackageSets.stable.lix "Which nix package to use.";
    extra-users = mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra users to trust";
    };
  };

  config = {
    # faster rebuilding
    documentation = {
      doc = disabled;
      info = disabled;
      man = mkDefault enabled;
    };

    environment.systemPackages = with pkgs; [
      git
      nixd
      nixfmt
      nix-index
      nix-prefetch-git
      cachix
      deploy-rs
    ];

    environment.etc =
      { }
      // mkIf isLinux {
        "nixos".source = self;
      }
      // mkIf isDarwin {
        "nix-darwin".source = self;
      };

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
        enable = mkDefault isLinux;

        settings = {
          trusted-users = users ++ cfg.extra-users;
          allowed-users = users;

          substituters = [
            "https://cache.nixos.org"
            "https://cache.lix.systems"
            "https://jmuchovej.cachix.org"
            "https://nix-community.cachix.org"
            "https://nixpkgs-unfree.cachix.org"
            "https://numtide.cachix.org"
          ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "cache.lix.systems-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "jmuchovej.cachix.org-1:NfwGBGTph5ztNzYL+xTteJeSOUPTK6U+rA8fItXmx6A="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
            "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
          ];

          extra-substituters = [
            "https://nixpkgs-python.cachix.org"
            "https://devenv.cachix.org"
            "https://cachix.cachix.org"
          ];
          extra-trusted-public-keys = [
            "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
            "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
            "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
          ];
          use-xdg-base-directories = true;
          experimental-features = [
            "nix-command"
            "flakes"
            "auto-allocate-uids"
            # "pipe-operators"
          ];
          # Automatically detect and use binary caches
          fallback = mkDefault true;
          # Continue building other derivations if one fails
          keep-going = mkDefault true;
          keep-derivations = mkDefault true;
          keep-outputs = mkDefault true;
          warn-dirty = mkDefault false;
          sandbox = mkDefault true;
          preallocate-contents = mkDefault true;
          log-lines = mkDefault 50;
          http-connections = mkDefault 0;
          flake-registry = "/etc/nix/registry.json";
          builders-use-substitutes = mkDefault true;
          # download-buffer-size = 500000000;

          auto-optimise-store = mkDefault isLinux;

          system-features = [
            "kvm"
            "big-parallel"
            "nixos-test"
          ];
        };

        checkConfig = true;
        nixPath = [ "/etc/nix/inputs" ];
        registry = mappedRegistry;

        optimise.automatic = mkDefault config.nix.enable;

        gc = {
          automatic = mkDefault config.nix.enable;
          options = mkDefault "--delete-older-than 7d";
        };
      };

    nixpkgs.hostPlatform = mkDefault system;
  };
}
