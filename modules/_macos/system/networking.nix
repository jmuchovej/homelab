{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "system.networking";
  config =
    { cfg, ... }:
    {
      networking.dns = [
        # "9.9.9.9"
        # "149.112.112.112" # Quad9
        # "1.1.1.1"
        # "1.0.0.1" # Cloudflare
      ];

      # firewall settings
      networking.applicationFirewall = {
        enable = true;
        blockAllIncoming = false;
        enableStealthMode = false;
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
