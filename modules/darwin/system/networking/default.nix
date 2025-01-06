{
  config,
  lib,
  namespace,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.system.networking;
in {
  options.${namespace}.system.networking = {
    enable = mkEnableOption "networking support";
  };

  config = mkIf cfg.enable {
    networking.dns = [
      "9.9.9.9"
      "149.112.112.112" # Quad9
      "1.1.1.1"
      "1.0.0.1" # Cloudflare
    ];

    system.defaults = {
      # firewall settings
      alf = {
        # 0 = disabled 1 = enabled 2 = blocks all connections except for essential services
        globalstate = 1;
        loggingenabled = 0;
        stealthenabled = 0;
      };
    };

    system.activationScripts.postActivation.text = ''
      echo "Checking if ssh is already loaded"
      if ! sudo launchctl list | grep -q ssh; then
        echo "Enabling ssh"
        sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist
      else
        echo "ssh is already loaded"
      fi
    '';
  };
}
