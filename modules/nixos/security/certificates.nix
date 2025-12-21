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
      inherit (lib.rebellion.file) get-file;

      traefik = config.rebellion.homelab.traefik;
      sopsFile = get-file "secrets/${datacenter}.sops.yaml";
      owner = "traefik";
    in
    {
      sops.secrets."certs/lab.key" = lib.mkIf (traefik.enable) {
        inherit sopsFile owner;
        mode = "0400";
      };
      sops.secrets."certs/lab.crt" = lib.mkIf (traefik.enable) {
        inherit sopsFile owner;
        mode = "0444";
      };
      security.pki.certificates = [
        (readFile (get-file "secrets/certificates/${datacenter}/ca.crt"))
      ];
    };
}
