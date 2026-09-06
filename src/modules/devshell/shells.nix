{ self, ... }: {
  perSystem =
    {
      config,
      inputs',
      pkgs,
      ...
    }:
    let
      # Bundle system CA certs with homelab CA for SSL trust
      caBundle =
        let
          homelabCA = "${self}/secrets/certificates/root.crt";
          systemCerts = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        in
        pkgs.runCommand "ca-bundle-with-homelab" { } ''
          cat ${systemCerts} > $out
          echo "" >> $out
          cat ${homelabCA} >> $out
        '';

      nushell-plugged =
        let
          inherit (pkgs) lib;
          inherit (pkgs.lib) getExe;
          plugins = with pkgs.nushellPlugins; [
            formats
            gstat
            polars
            query
          ];
        in
        pkgs.writeShellScriptBin "nu" ''
          exec ${getExe pkgs.nushell} --plugins '[${lib.concatMapStringsSep " " getExe plugins}]' "$@"
        '';

      openspec = inputs'.llm-agents.packages.openspec;

      # Project skills for the shared `.agents/skills` root: hand-written ones
      # from the top-level `skills/` directory plus openspec's workflow skills,
      # rendered from the same openspec the shell ships.
      homelab-skills = pkgs.symlinkJoin {
        name = "homelab-skills";
        paths = [
          (builtins.path {
            name = "homelab-skills-local";
            path = "${self}/skills";
            filter = path: _type: baseNameOf path != ".gitkeep";
          })
          (pkgs.callPackage ./_skills/openspec.nix { inherit openspec; })
        ];
      };
    in
    {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          # Nix workflows
          nh
          cachix
          nix-output-monitor
          nix-tree
          nix-diff
          inputs'.nix-unit.packages.default

          # VCS / repo tooling
          git
          jujutsu
          just

          # Formatting / pre-commit
          config.treefmt.build.wrapper
          prek

          # Secrets
          sops
          age
          ssh-to-age
          ssh-to-pgp
          mkpasswd
          gum
          # mints Syncthing device identities (`just secrets syncthing-identity`)
          syncthing

          # Service mesh
          consul
          nomad
          openbao

          # IaC / deploy
          opentofu
          deploy-rs

          # Networking / WireGuard (wg-holonet key gen + diagnostics)
          wireguard-tools

          # Python (homelab CLI + docs via `uv run`)
          python313
          uv

          # Diagrams / docs
          d2
          nixos-render-docs

          # AI tooling
          openspec

          # Misc
          tmux
          fd
          nushell-plugged
          gettext # envsubst — used by mikrotik bootstrap recipe
        ];

        env = {
          NIX_SSL_CERT_FILE = "${caBundle}";
          SSL_CERT_FILE = "${caBundle}";
          TREEFMT_ALLOW_MISSING_FORMATTER = "1";
        };

        shellHook = ''
          ${config.pre-commit.installationScript}

          # Project skills live in one shared root, `.agents/skills`, which
          # Antigravity and Codex read natively. Harnesses that only look in
          # their own directory get a symlink to it. A path that exists and is
          # not a symlink is left alone rather than clobbered.
          link_skills() {
            if [ -e "$2" ] && [ ! -L "$2" ]; then
              echo "skills: $2 exists and is not a symlink; not replacing it" >&2
              return 0
            fi
            mkdir -p "$(dirname "$2")"
            ln -snf "$1" "$2"
          }
          link_skills "${homelab-skills}" .agents/skills
          link_skills "$PWD/.agents/skills" .claude/skills
        '';
      };
    };
}
