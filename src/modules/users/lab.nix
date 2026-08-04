{
  lib,
  den,
  __findFile,
  ...
}:
{
  den.aspects.lab = {
    meta = {
      username = "lab";
      authorized-keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3FPLe1ZXSk7KBgSkJud2hlvUAGF5m57g2Pqpccy5SO"
      ];
    };

    includes = [
      <rbn/suite/common>
      <rbn/suite/development>
      (den.batteries.user-shell "zsh")

      # Terminal programs
      <rbn/programs/terminal/zellij>
      <rbn/programs/terminal/bacon>
      <rbn/programs/terminal/k9s>
      <rbn/programs/terminal/topgrade>

      # Core
      <rbn/programs/ai-tools/claude/code>
      <rbn/programs/ai-tools/mcp>

      # Editors
      <rbn/programs/editors/helix>
      <rbn/programs/editors/micro>
      (<rbn/programs/editors/default-editor> "nvim")
    ];

    # `lab` is the local admin/deploy account. Its home lives at /lab — off
    # the /home tree — so it never depends on the NFS /home mount that serves
    # LDAP-provided users. A NAS outage then can't lock the admin out or break
    # activation (NixOS no longer mkdir's a managed home under NFS). den's
    # define-user battery hardcodes /home/<user>, so force the override at both
    # the OS and home-manager levels (they must agree).
    nixos =
      {
        host,
        lib,
        pkgs,
        ...
      }:
      lib.mkMerge [
        {
          users.users.lab = {
            home = lib.mkForce "/lab";
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3FPLe1ZXSk7KBgSkJud2hlvUAGF5m57g2Pqpccy5SO"
            ];
          };

          # lab's home-manager sops runs as the lab user, which can't read the
          # root-only host key — so user-level sops has no usable key and fails
          # ("permission denied" on /etc/ssh/...). Derive lab's age identity from
          # the host key (root can read it) into lab's keyFile path. The host key
          # is already a recipient of secrets/users/lab.sops.yaml on every node,
          # so this lets the user-sops decrypt. Runs before home-manager-lab
          # (which triggers the user sops-nix) and after /lab is mounted.
          systemd.services.lab-sops-age-key = {
            before = [ "home-manager-lab.service" ];
            unitConfig.RequiresMountsFor = [ "/lab" ];
            serviceConfig = {
              Type = "oneshot";
              # RemainAfterExit so `switch-to-configuration` treats this as a
              # unit that should be active (a bare oneshot is skipped on a live
              # switch), and so home-manager-lab's Requires below stays satisfied.
              RemainAfterExit = true;
            };
            script = ''
              # /persist holds the real key on impermanence hosts (the /etc/ssh
              # copy is a late bind-mount); fall back to /etc/ssh elsewhere.
              key=/etc/ssh/ssh_host_ed25519_key
              [ -r /persist/etc/ssh/ssh_host_ed25519_key ] && key=/persist/etc/ssh/ssh_host_ed25519_key
              install -d -o lab -g users -m 0700 /lab/.config/sops/age
              umask 077
              ${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i "$key" > /lab/.config/sops/age/keys.txt
              chown lab:users /lab/.config/sops/age/keys.txt
              chmod 0600 /lab/.config/sops/age/keys.txt
            '';
          };

          # home-manager-lab triggers the user sops-nix, which needs the key
          # above. `Before` alone fails on a live `switch`: switch-to-configuration
          # restarts the (changed) home-manager-lab in a different phase than it
          # starts the (new) key service, so the key never lands first. Making
          # home-manager-lab `requires` + `after` the key service forces the
          # restart to pull the key service in (and run it) ahead of activation.
          systemd.services.home-manager-lab = {
            requires = [ "lab-sops-age-key.service" ];
            after = [ "lab-sops-age-key.service" ];
          };
        }
        # Persist the admin home across the impermanence rollback on every host
        # that has persistence enabled (appends to the per-host directory list).
        # optionalAttrs (not mkIf): hosts without impermanence don't import the
        # module, so `environment.persistence` doesn't exist there — a `mkIf
        # false` still trips the option-existence check, but optionalAttrs omits
        # the definition entirely.
        (lib.optionalAttrs (host.persistence != null) {
          # Attrset form (not a bare string): impermanence creates the persisted
          # source owned by lab:users. A bare string defaults to root:root, and
          # since the bind-mount makes /lab pre-exist, NixOS's user step won't
          # chown it — leaving lab unable to write ~/.local/state and breaking
          # home-manager activation.
          environment.persistence."/persist".directories = [
            {
              directory = "/lab";
              user = "lab";
              group = "users";
              mode = "0700";
            }
          ];
        })
      ];

    homeManager.home.homeDirectory = lib.mkForce "/lab";
  };

  den.hosts.x86_64-linux.da-vcx-1.users.lab = { };
  den.hosts.x86_64-linux.da-vcx-2.users.lab = { };
  den.hosts.x86_64-linux.da-vcx-3.users.lab = { };
  den.hosts.x86_64-linux.da-gr75.users.lab = { };

  den.hosts.x86_64-linux.en-t65-1.users.lab = { };
}
