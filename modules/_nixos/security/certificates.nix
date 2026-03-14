{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "security.certificates";
  config =
    {
      lib,
      datacenter,
      config,
      ...
    }:
    let
      inherit (builtins) readFile;
      inherit (lib) mkIf mkMerge;
      inherit (lib.rebellion.fs) get-file get-secret;

      inherit (config.rebellion.services) traefik;
      sops-opts = {
        owner = "traefik";
        mode = "0400";
      };
    in
    mkMerge [
      {
        security.pki.certificates = [
          (readFile (get-file "secrets/certificates/${datacenter}/ca.crt"))
        ];
      }
      (mkIf traefik.enable (get-secret config "certs/lab.key" datacenter) // sops-opts)
      (mkIf traefik.enable (get-secret config "certs/lab.crt" datacenter) // sops-opts)
    ];
}
