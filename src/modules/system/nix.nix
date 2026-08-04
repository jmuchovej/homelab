{ inputs, lib, ... }:
{
  flake-file.inputs = {
    nix-index-database.url = "github:nix-community/nix-index-database";
    nh.url = "github:nix-community/nh";
  };

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

        extraOptions = ''
          !include ${config.sops.secrets."nix-access-tokens".path}
        '';
      };
    };

  # `den.default.homeManager` above enables HM's `nix` module for every home, and
  # HM then asserts `nix.package != null` because it runs `nix show-config` from
  # that package to validate the nix.conf it generates. On a host, the NixOS /
  # nix-darwin home-manager integration supplies it; a standalone `den.homes.*`
  # entry has no system nix behind it and has to name one itself.
  #
  # Scoped to `den.schema.home` on purpose — setting `nix.package` unconditionally
  # would also apply on hosts, where HM currently defers to the system.
  den.schema.home.includes = [
    {
      name = "standalone-home/nix-package";
      homeManager =
        { lib, pkgs, ... }:
        {
          nix.package = lib.mkDefault pkgs.lixPackageSets.stable.lix;
        };
    }
  ];

  rbn.system._.nix = {
    os =
      {
        host,
        pkgs,
        system,
        ...
      }:
      let
        substituters = {
          "cache.nixos.org" = "1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
          # "cache.lix.systems" = "1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
          "jmuchovej.cachix.org" = "1:NfwGBGTph5ztNzYL+xTteJeSOUPTK6U+rA8fItXmx6A=";
          "nix-community.cachix.org" = "1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
          "nixpkgs-unfree.cachix.org" = "1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs=";
          "numtide.cachix.org" = "1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=";
        };
        extra-substituters = {
          "devenv.cachix.org" = "1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
          "nixpkgs-python.cachix.org" = "1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU=";
          "cachix.cachix.org" = "1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM=";
        };
        substituter-urls = subs: map (sub: "https://${sub}") (lib.attrNames subs);
        substituter-keys = subs: lib.mapAttrsToList (domain: pkey: "${domain}-${pkey}") subs;
      in
      {
        # Faster rebuilding
        documentation = {
          doc.enable = false;
          info.enable = false;
          man.enable = lib.mkDefault true;
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

        # Backs `nix.nixPath` below so `<nixpkgs>` and `nix-shell -p` resolve
        # to the same nixpkgs the system was built from.
        environment.etc."nix/inputs/nixpkgs".source = inputs.nixpkgs;

        nixpkgs.hostPlatform = lib.mkDefault system;

        nix = {
          package = lib.mkDefault pkgs.lixPackageSets.stable.lix;
          enable = lib.mkDefault true;

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

            substituters = substituter-urls substituters;
            trusted-public-keys = substituter-keys substituters;

            extra-substituters = substituter-urls extra-substituters;
            extra-trusted-public-keys = substituter-keys extra-substituters;

            use-xdg-base-directories = true;
            experimental-features = [
              "nix-command"
              "flakes"
              "auto-allocate-uids"
            ];
            fallback = lib.mkDefault true;
            keep-going = lib.mkDefault true;
            keep-derivations = lib.mkDefault true;
            keep-outputs = lib.mkDefault true;
            warn-dirty = lib.mkDefault false;
            sandbox = lib.mkDefault "relaxed";
            preallocate-contents = lib.mkDefault true;
            log-lines = lib.mkDefault 50;
            http-connections = lib.mkDefault 0;
            flake-registry = "/etc/nix/registry.json";
            builders-use-substitutes = lib.mkDefault true;

            system-features = [
              "kvm"
              "big-parallel"
              "nixos-test"
            ];
          };

          checkConfig = true;
          nixPath = [ "/etc/nix/inputs" ];

          registry = lib.pipe inputs [
            (lib.filterAttrs (_: lib.isType "flake"))
            (lib.mapAttrs (_: flake: { inherit flake; }))
            # No-op while an input named `nixpkgs` exists; load-bearing the
            # moment that input is renamed or split.
            (reg: reg // { nixpkgs.flake = inputs.nixpkgs; })
          ];

          optimise.automatic = true;

          gc = {
            automatic = true;
            options = lib.mkDefault "--delete-older-than 7d";
          };
        };
      };

    nixos = { lib, pkgs, ... }: {
      environment.systemPackages = [
        (pkgs.writeShellApplication {
          name = "known-good";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.lixPackageSets.stable.lix
          ];
          text = builtins.readFile ./known-good.sh;
        })
      ];
      environment.etc."nixos".source = inputs.self;

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

    darwin = {
      environment.etc."nix-darwin".source = inputs.self;

      nix = {
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
