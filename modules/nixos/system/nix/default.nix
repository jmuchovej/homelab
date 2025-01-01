{ options, config, pkgs, lib, namespace, ... }:
let
  inherit (lib) types mkDefault mkIf mkEnableOption mkPackageOption mkOption;

  cfg = config.${namespace}.system.nix;
in {
  options.${namespace}.system.nix = with types; {
    enable = mkEnableOption "manage nix configuration" // { default = true; };
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
    environment.systemPackages = with pkgs; [
      nil
      nixfmt-rfc-style
      nix-index
      nix-prefetch-git
      cachix
      deploy-rs
    ];

    nix = let
      users = [ "root" config.${namespace}.user.name ];
    in {
      inherit (cfg) package;

      settings = {
        auto-optimise-store       = mkDefault true;
        use-xdg-base-directories  = true;
        experimental-features     = [ "nix-command" "flakes" ];
        warn-dirty                = false;
        log-lines                 = 50;
        http-connections          = 50;
        # trusted-users             = [ "@wheel" "root" ];
        trusted-users             = users ++ cfg.extra-users;
        allowed-users             = users;
      }; # // (lib.optionalAttrs config.${namespace}.apps.tools.direnv.enable {
      #   keep-outputs      = true;
      #   keep-derivations  = true;
      # });

      gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };

      # flake-utils-plus
      generateRegistryFromInputs  = true;
      generateNixPathFromInputs   = true;
      linkInputs                  = true;
    };
  };
}
