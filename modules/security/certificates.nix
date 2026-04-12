# Consolidated CA certificate installation across NixOS and darwin.
_:
let
  mkCertConfig =
    { lib, host, ... }:
    let
      inherit (builtins) readFile;
      inherit (lib.rebellion.fs) get-file;
    in
    {
      security.pki.certificates = [
        (readFile (get-file "secrets/certificates/${host.datacenter}/ca.crt"))
      ];
    };
in
{
  rbn.security._.certificates = {
    nixos =
      {
        host,
        config,
        lib,
        ...
      }@args:
      let
        inherit (lib) mkIf mkMerge;
        inherit (lib.rebellion.fs) get-file;

        traefik = host.traefik or { enable = false; };
        sopsFile = get-file "secrets/${host.datacenter}.sops.yaml";
      in
      mkMerge [
        (mkCertConfig args)
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

    darwin =
      args:
      (mkCertConfig args)
      // {
        security.pki.installCACerts = true;
      };
  };
}
