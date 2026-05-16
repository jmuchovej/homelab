{ __findFile, ... }:
{
  den.hosts.x86_64-linux.bootstrap = { };

  den.aspects.bootstrap = {
    nixos =
      { modulesPath, lib, pkgs, ... }:
      {
        imports = [
          (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
        ];

        # Drop to an emergency shell if stage-1 (initrd) fails, instead of
        # rebooting — UEFI marks the entry failed after two reboot loops and
        # falls through to firmware setup, hiding the actual panic.
        boot.kernelParams = [ "boot.shell_on_fail" ];

        networking.hostName = lib.mkForce "rbn-bootstrap";

        users.users.lab = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = [
            (lib.fileContents ../../../../secrets/keys/iso-key.pub)
          ];
        };

        users.users.root.openssh.authorizedKeys.keys = [
          (lib.fileContents ../../../../secrets/keys/iso-key.pub)
        ];

        security.sudo.wheelNeedsPassword = false;

        services.openssh = {
          enable = true;
          settings.PermitRootLogin = lib.mkForce "prohibit-password";
        };

        # Replace upstream's password-help text with our banner. agetty's
        # \4 escape resolves to the first IPv4 — useful at the pre-login
        # prompt, but autologin hides it fast, so the real banner is the
        # bash one below.
        services.getty.helpLine = lib.mkForce ''

          ┌────────────────────────────────────────────────┐
          │  Rebellion Bootstrap ISO                       │
          │  IPv4: \4                                      │
          └────────────────────────────────────────────────┘
        '';

        # Re-print the banner every time an interactive bash shell starts,
        # so the autologin console always lands the operator on a screen
        # that shows the IP — regardless of how quickly the shell prompt
        # paints over the agetty issue.
        programs.bash.interactiveShellInit = ''
          if [ -z "''${RBN_BANNER_SHOWN:-}" ]; then
            export RBN_BANNER_SHOWN=1
            _rbn_ip=$(ip -4 -brief addr show scope global \
                       | awk '{print $3}' | head -n1 | cut -d/ -f1)
            echo
            echo "┌────────────────────────────────────────────────┐"
            echo "│  Rebellion Bootstrap ISO                       │"
            echo "│  IPv4:  ''${_rbn_ip:-<no link yet>}"
            echo "│  SSH:   root@''${_rbn_ip:-<addr>}  (key: iso-key)"
            echo "│  From your workstation:                        │"
            echo "│      homelab bootstrap host <name> ''${_rbn_ip:-<addr>}"
            echo "└────────────────────────────────────────────────┘"
            echo
            unset _rbn_ip
          fi
        '';

        # Ensure `ip` and `awk` are available without needing absolute paths
        # in the banner — keeps the interactiveShellInit closure small enough
        # to fit under Nix's 211-char derivation-name limit.
        environment.systemPackages = with pkgs; [
          iproute2
          gawk
        ];

        system.stateVersion = "24.05";
      };
  };
}
