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
          inherit (pkgs.lib) getExe concatMapStringsSep;
          plugins = with pkgs.nushellPlugins; [
            formats
            gstat
            polars
            query
          ];
        in
        pkgs.writeShellScriptBin "nu" ''
          exec ${getExe pkgs.nushell} --plugins '[${concatMapStringsSep " " getExe plugins}]' "$@"
        '';

      openspec = inputs'.llm-agents.packages.openspec;
    in
    {
      devShells.default = pkgs.mkShell {
        inputsFrom = [ config.devShells.formatting ];
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

          # Pre-commit (formatters come from devShells.formatting)
          prek
          zizmor

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
          # `just bootstrap nix install`: nixos-anywhere itself, and an
          # OpenSSL-linked ssh-keygen (Apple's cannot read PKCS#8 host keys)
          nixos-anywhere
          openssh

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
        };

        shellHook = ''
          ${config.pre-commit.installationScript}
        '';
      };
    };
}
