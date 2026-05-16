{ self, ... }:
{
  perSystem =
    {
      config,
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

          # Misc
          tmux
          fd
          gettext # envsubst — used by mikrotik bootstrap recipe
        ];

        env = {
          NIX_SSL_CERT_FILE = "${caBundle}";
          SSL_CERT_FILE = "${caBundle}";
          TREEFMT_ALLOW_MISSING_FORMATTER = "1";
        };

        shellHook = ''
          ${config.pre-commit.installationScript}

          # Sync project-specific skills into tool-specific locations.
          # TODO(jmuchovej): This only supports Claude Code, which has native skill
          # discovery via `.claude/skills/`. Gemini CLI and OpenCode don't have an
          # equivalent mechanism — supporting them would require running skills through
          # the Nix rendering pipeline (`modules/ai-tools/_ai-tools/lib.nix`) to transform
          # them into each tool's format (e.g., Gemini commands, OpenCode agents).
          mkdir -p .claude
          rm -rf .claude/skills
          ln -snf "$(pwd)/skills" .claude/skills
        '';
      };
    };
}
