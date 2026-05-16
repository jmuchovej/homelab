# Consolidated Nix configuration: package, caches, registry, GC, daemon tuning.
{ inputs, lib, ... }:
{
  flake-file.inputs = {
    nix-index-database.url = "github:nix-community/nix-index-database";
    nh.url = "github:nix-community/nh";
  };

  # ── Module imports per class ──────────────────────────────────────
  den.default.nixos = {
    imports = [ inputs.nix-index-database.nixosModules.nix-index ];
    programs.nix-index-database.comma.enable = true;
    programs.nix-ld.enable = true;
  };

  den.default.darwin = {
    imports = [ inputs.nix-index-database.darwinModules.nix-index ];
    programs.nix-index-database.comma.enable = true;
  };

  den.default.homeManager =
    { config, lib, ... }:
    {
      imports = [ inputs.nix-index-database.homeModules.nix-index ];
      programs.nix-index-database.comma.enable = true;
      home.preferXdgDirectories = lib.mkDefault true;
      nix = {
        enable = lib.mkDefault true;

        settings = {
          use-xdg-base-directories = true;
          warn-dirty = false;
        };

        # Pull in sops-rendered tokens (e.g. github.com access-tokens).
        # HM owns the rest of nix.conf; this only appends an `!include`.
        extraOptions = ''
          !include ${config.sops.secrets."nix-access-tokens".path}
        '';
      };
    };

  # ── Nix aspect ────────────────────────────────────────────────────
  rbn.system._.nix = {
    # Shared across NixOS and darwin
    os =
      {
        host,
        pkgs,
        system,
        ...
      }:
      let
        inherit (lib)
          mkDefault
          mkIf
          pipe
          filterAttrs
          mapAttrs
          isType
          ;
        inherit (pkgs.stdenv) isLinux isDarwin;

        # Nix registry: map all flake inputs + remap nixpkgs
        remap-nixpkgs = reg: reg // { nixpkgs.flake = inputs.nixpkgs; };
        drop-unstable-macos = reg: if isDarwin then removeAttrs reg [ "nixpkgs-unstable" ] else reg;
        mappedRegistry = pipe inputs [
          (filterAttrs (_: isType "flake"))
          (mapAttrs (_: flake: { inherit flake; }))
          remap-nixpkgs
          drop-unstable-macos
        ];
      in
      {
        # Faster rebuilding
        documentation = {
          doc.enable = false;
          info.enable = false;
          man.enable = mkDefault true;
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
          mkIf isLinux { "nixos".source = inputs.self; }
          // mkIf isDarwin { "nix-darwin".source = inputs.self; };

        nixpkgs.hostPlatform = mkDefault system;

        nix = {
          package = mkDefault pkgs.lixPackageSets.stable.lix;
          enable = mkDefault isLinux;

          settings = {
            trusted-users = [
              "root"
              "@wheel"
              "nix-builder"
              host.primary-user.name
            ];
            allowed-users = [
              "root"
              "@wheel"
              "nix-builder"
              host.primary-user.name
            ];

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
            ];
            fallback = mkDefault true;
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

          optimise.automatic = true;

          gc = {
            automatic = true;
            options = mkDefault "--delete-older-than 7d";
          };
        };
      };

    # NixOS-specific daemon tuning
    nixos =
      { lib, ... }:
      {
        documentation.nixos = {
          enable = true;
          options = {
            warningsAreErrors = true;
            splitBuild = true;
          };
        };

        nix = {
          daemonCPUSchedPolicy = "batch";
          daemonIOSchedClass = "idle";
          daemonIOSchedPriority = 7;

          gc.dates = [ "weekly" ];
          optimise.dates = [ "04:00" ];

          settings = {
            auto-optimise-store = lib.mkDefault true;
            log-lines = 50;
            http-connections = 50;
            experimental-features = [ "cgroups" ];
            use-cgroups = true;
          };
        };
      };

    # darwin-specific nix settings
    darwin = {
      nix = {
        enable = true;

        settings = {
          max-jobs = "auto";
          cores = 0;

          extra-sandbox-paths = [
            "/System/Library/Frameworks"
            "/System/Library/PrivateFrameworks"
            "/usr/lib"
            "/private/tmp"
            "/private/var/tmp"
            "/usr/bin/env"
          ];

          connect-timeout = 10;
        };

        gc = {
          automatic = true;
          interval = {
            Weekday = 0;
            Hour = 0;
            Minute = 0;
          };
          options = "--delete-older-than 7d";
        };

        optimise.automatic = true;

        linux-builder = {
          enable = true;
          ephemeral = true;
          maxJobs = 4;
          config = {
            virtualisation = {
              darwin-builder.diskSize = 40 * 1024;
              darwin-builder.memorySize = 8 * 1024;
            };
          };
        };
      };
    };
  };
}
