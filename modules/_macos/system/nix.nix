{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "system.nix";
  always-active = true;
  imports = [ (lib.rebellion.fs.get-file "modules/_common/system/nix.nix") ];
  config = _: {
    nix = {
      # Enable nix-darwin to manage nix configuration
      # This will write settings to /etc/nix/nix.conf or nix.custom.conf
      # depending on the Determinate Nix installation
      enable = true;

      # Additional settings specific to macOS
      settings = {
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
  };
}
