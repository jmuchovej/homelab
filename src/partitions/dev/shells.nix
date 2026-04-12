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
          homelabCA = "${self}/secrets/certificates/da/ca.crt";
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
          nixos-render-docs
          d2
          git
          sops
          tmux
          ssh-to-age
          ssh-to-pgp
          age
          python3
          opentofu
          prek
          consul
          nomad
          openbao
          mkpasswd
          config.treefmt.build.wrapper
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
