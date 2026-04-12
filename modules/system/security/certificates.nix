# Consolidated CA certificate installation across NixOS and darwin.
_:
let
  mkCertConfig =
    { host, lib, ... }:
    let
      inherit (builtins) readFile;
      inherit (lib.rbn) get-file;
    in
    {
      security.pki.certificates = [
        (readFile (get-file "secrets/certificates/${host.datacenter}/ca.crt"))
      ];
    };
in
{
  rbn.system._.security._.certificates = {
    nixos =
      {
        host,
        config,
        lib,
        ...
      }@args:
      let
        inherit (lib) mkIf mkMerge;
        inherit (lib.rbn) get-file;

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
