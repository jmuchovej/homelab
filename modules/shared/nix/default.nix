{
  config,
  inputs,
  lib,
  pkgs,
  namespace,
  host,
  ...
}:
let
  inherit (lib)
    mkIf mkDefault mkEnableOption mkOption mkPackageOption types
    pipe isType
    filterAttrs mapAttrs removeAttrs mapAttrsToList
    ;
  inherit (lib.${namespace}) enabled disabled;
  inherit (pkgs.stdenv) isLinux isDarwin;

  cfg = config.${namespace}.nix;

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
in
{
  options.${namespace}.nix = with types; {
    enable  = mkEnableOption "manage nix configuration" // { default = true; };
    package = mkPackageOption pkgs "nixVersions" {
      default = [ "nixVersions" "latest" ];
    };
    extra-users = mkOption {
      type = (listOf str);
      default = [ ];
      description = "Extra users to trust";
    };
  };

  config = mkIf cfg.enable {
    # faster rebuilding
    documentation = {
      doc   = disabled;
      info  = disabled;
      man   = mkDefault enabled;
    };

    environment.etc = (with inputs;
      {
        # set channels (backwards compatibility)
        "nix/flake-channels/system".source = self;
        "nix/flake-channels/nixpkgs".source = nixpkgs;
        "nix/flake-channels/home-manager".source = home-manager;
      }
      # preserve current flake in /etc
      // mkIf isLinux {
        "nixos/flake".source = self;
      }
    );

    environment.systemPackages = (with pkgs; [
      nil
      nixfmt-rfc-style
      nix-index
      nix-prefetch-git
      cachix
      deploy-rs
    ]);

    nix = let
      users = [ "root" "@wheel" "nix-builder" config.${namespace}.user.name ];
    in {
      inherit (cfg) package;

      # distributedBuilds = true;

      gc = {
        automatic = true;
        options = "--delete-older-than 7d";
      };

      # This will additionally add your inputs to the system's legacy channels
      # Making legacy nix commands consistent as well
      # nixPath = mapAttrsToList
      #   (key: _: "${key}=flake:${key}")
      #   config.nix.registry;

      optimise.automatic = true;

      # pin the registry to avoid downloading and evaluating a new nixpkgs version every time
      # this will add each flake input as a registry to make nix3 commands consistent with your flake
      # registry = mappedRegistry;

      settings = {
        auto-optimise-store       = isLinux;
        builders-use-substitutes  = true;
        experimental-features     = [ "nix-command" "flakes" ];
        flake-registry            = "/etc/nix/registry.json";
        http-connections          = 50;
        keep-derivations          = true;
        keep-going                = true;
        keep-outputs              = true;
        log-lines                 = 50;
        sandbox                   = true;
        trusted-users             = users ++ cfg.extra-users;
        allowed-users             = users;
        warn-dirty                = false;

        substituters = [
          "https://cache.nixos.org"
          "https://jmuchovej.cachix.org"
          "https://nix-community.cachix.org"
          "https://nixpkgs-unfree.cachix.org"
          "https://numtide.cachix.org"
        ];

        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "jmuchovej.cachix.org-1:NfwGBGTph5ztNzYL+xTteJeSOUPTK6U+rA8fItXmx6A="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
          "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
        ];

        use-xdg-base-directories = true;
      };

      # flake-utils-plus
      generateRegistryFromInputs  = true;
      generateNixPathFromInputs   = true;
      linkInputs                  = true;
    };

    programs.ssh.knownHosts = {
      # "aarch64.nixos.community".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMUTz5i9u5H2FHNAmZJyoJfIGyUm/HfGhfwnc142L3ds";
      # "darwin-build-box.nix-community.org".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFz8FXSVEdf8FvDMfboxhB5VjSe7y2WgSa09q1L4t099";
      "da-n1x".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuCsYqoRhddcQdd2V8uFfszEgIJSP3mnlWNttQBwiUb";
      # "da-vcx-1".publicKey = "";
      # "da-vcx-2".publicKey = "";
      # "da-vcx-3".publicKey = "";
      # "en-t65-1".publicKey = "";
    };
  };
}
