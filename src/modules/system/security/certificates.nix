{
  rbn.system._.security._.certificates =
    let
      mk-cert-config =
        { lib, ... }:
        let
          inherit (builtins) readFile;
          inherit (lib.rbn) get-file;
        in
        {
          security.pki.certificates = [
            (readFile (get-file "secrets/certificates/root.crt"))
          ];
        };
    in
    {
      nixos =
        { host, lib, ... }@args:
        let
          inherit (lib) mkIf mkMerge;
          inherit (lib.rbn) get-file;

          traefik = host.traefik or { enable = false; };
          sopsFile = get-file "secrets/${host.datacenter}.sops.yaml";
        in
        mkMerge [
          (mk-cert-config args)
          (mkIf (traefik.enable or false) {
            sops.secrets."certs/lab.key" = {
              inherit sopsFile;
              owner = "traefik";
              mode = "0400";
            };
            sops.secrets."certs/lab.crt" = {
              inherit sopsFile;
              owner = "traefik";
              mode = "0400";
            };
          })
        ];

      macos =
        args:
        (mk-cert-config args)
        // {
          security.pki.installCACerts = true;
        };
    };
}
