{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) get-file;

  cfg = config.rebellion.system.nix;
in
{
  imports = [ (get-file "modules/common/system/nix.nix") ];

  config = mkIf cfg.enable {
    nix = {
      # Enable nix-darwin to manage nix configuration
      # This will write settings to /etc/nix/nix.conf or nix.custom.conf
      # depending on the Determinate Nix installation
      enable = true;

      # Additional settings specific to macOS
      # These will be written to the configuration file
      settings = {
        # macOS-specific optimizations
        max-jobs = "auto";
        cores = 0; # Use all available cores

        extra-sandbox-paths = [
          "/System/Library/Frameworks"
          "/System/Library/PrivateFrameworks"
          "/usr/lib"

          "/private/tmp"
          "/private/var/tmp"
          "/usr/bin/env"
        ];

        # Bail early on missing cache hits
        connect-timeout = 10;
      };

      # Extra options that might not be supported through settings
      # extraOptions = ''
      #   # Bail early on missing cache hits
      #   connect-timeout = 10
      # '';

      # Configure garbage collection for the user
      gc = {
        automatic = true;
        interval = {
          Weekday = 0;
          Hour = 0;
          Minute = 0;
        };
        options = "--delete-older-than 7d";
      };

      # Configure store optimization
      optimise.automatic = true;
    };

    # Note: linux-builder configuration can be added here if needed
    # nix.linux-builder = {
    #   enable = true;
    #   package = pkgs.darwin.linux-builder;
    # };
  };
}
