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
        '';
      };
    };
}
