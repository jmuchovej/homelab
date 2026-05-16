_: {
  den.hosts.x86_64-linux.bootstrap = { };

  den.aspects.bootstrap = {
    nixos =
      {
        modulesPath,
        lib,
        pkgs,
        ...
      }:
      let
        # Mount the standard rebellion impermanence layout (@, @nix, @persist,
        # plus EFI) under <mountpoint>. Defaults to /mnt.
        rescue-mount = pkgs.writeShellApplication {
          name = "rbn-rescue-mount";
          runtimeInputs = with pkgs; [
            util-linux
            btrfs-progs
          ];
          text = ''
            MNT="''${1:-/mnt}"
            DEV=/dev/disk/by-partlabel/NixOS
            EFI=/dev/disk/by-partlabel/EFI

            mkdir -p "$MNT"/{nix,persist,boot}
            mount -o subvol=@        "$DEV" "$MNT"
            mount -o subvol=@nix     "$DEV" "$MNT/nix"
            mount -o subvol=@persist "$DEV" "$MNT/persist"
            mount                    "$EFI" "$MNT/boot"

            echo
            echo "Installed system mounted at $MNT:"
            findmnt -R "$MNT" -o TARGET,SOURCE,OPTIONS | head -10
          '';
        };

        rescue-umount = pkgs.writeShellApplication {
          name = "rbn-rescue-umount";
          runtimeInputs = with pkgs; [ util-linux ];
          text = ''
            MNT="''${1:-/mnt}"
            umount -R "$MNT" 2>/dev/null || true
            echo "Unmounted $MNT (if it was mounted)"
          '';
        };

        rescue-enter = pkgs.writeShellApplication {
          name = "rbn-rescue-enter";
          runtimeInputs = with pkgs; [ util-linux ];
          text = ''
            MNT="''${1:-/mnt}"
            if ! mountpoint -q "$MNT"; then
              ${rescue-mount}/bin/rbn-rescue-mount "$MNT"
            fi
            exec nixos-enter --root "$MNT"
          '';
        };

        banner = pkgs.writeShellScriptBin "rbn-banner" ''
          _rbn_ip=$(${pkgs.iproute2}/bin/ip -4 -brief addr show scope global \
                     | ${pkgs.gawk}/bin/awk '{print $3}' | head -n1 | cut -d/ -f1)
          cat <<EOF

          ┌──────────────────────────────────────────────────────┐
          │  Rebellion Bootstrap ISO                             │
          │  IPv4:  ''${_rbn_ip:-<no link yet>}
          │  SSH:   root@''${_rbn_ip:-<addr>}  (key: iso-key)
          │                                                      │
          │  Install a new host (from your workstation):         │
          │    homelab bootstrap host <name> ''${_rbn_ip:-<addr>}
          │                                                      │
          │  Rescue an existing install:                         │
          │    rbn-rescue-mount [mnt]   # mount @,@nix,@persist  │
          │    rbn-rescue-enter  [mnt]  # mount + nixos-enter    │
          │    rbn-rescue-umount [mnt]  # tidy up                │
          └──────────────────────────────────────────────────────┘

          EOF
        '';
      in
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
          shell = pkgs.zsh;
          openssh.authorizedKeys.keys = [
            (lib.fileContents ../../../../secrets/keys/iso-key.pub)
          ];
        };

        users.users.root = {
          shell = pkgs.zsh;
          openssh.authorizedKeys.keys = [
            (lib.fileContents ../../../../secrets/keys/iso-key.pub)
          ];
        };

        security.sudo.wheelNeedsPassword = false;

        services.openssh = {
          enable = true;
          settings.PermitRootLogin = lib.mkForce "prohibit-password";
        };

        programs.zsh = {
          enable = true;
          enableCompletion = true;
          autosuggestions.enable = true;
          syntaxHighlighting.enable = true;

          interactiveShellInit = ''
            source ${pkgs.fzf}/share/fzf/key-bindings.zsh
            source ${pkgs.fzf}/share/fzf/completion.zsh
            eval "$(zoxide init zsh)"
          '';
        };

        environment.shellAliases = {
          ls = "eza";
          ll = "eza -l --git";
          la = "eza -la --git";
          tree = "eza --tree";
          cat = "bat --paging=never";
        };

        environment.variables = {
          EDITOR = "nvim";
          VISUAL = "nvim";
          PAGER = "less";
        };

        # Replace upstream's password-help text with the rebellion banner.
        # `\4` is agetty's first-IPv4 escape — useful pre-login.
        services.getty.helpLine = lib.mkForce ''
          ┌────────────────────────────────────────────────┐
          │  Rebellion Bootstrap ISO                       │
          │  IPv4: \4                                      │
          └────────────────────────────────────────────────┘
        '';

        environment.interactiveShellInit = ''
          if [ -z "''${RBN_BANNER_SHOWN:-}" ]; then
            export RBN_BANNER_SHOWN=1
            ${banner}/bin/rbn-banner
          fi
        '';

        environment.systemPackages = with pkgs; [
          # Banner + rescue scripts dependencies (bare commands, since the
          # shell-init refers to them by name; absolute paths inflate the
          # closure past Nix's 211-char NAME_MAX).
          iproute2
          gawk
          util-linux
          btrfs-progs

          # Editing + monitoring during rescue
          neovim
          btop
          tmux

          # QoL — match daily-driver shell expectations so rescue work
          # doesn't trip on muscle-memory mismatches.
          eza
          bat
          fzf
          zoxide
          ripgrep
          fd

          # The scripts themselves
          rescue-mount
          rescue-umount
          rescue-enter
          banner
        ];

        system.stateVersion = "24.05";
      };
  };
}
