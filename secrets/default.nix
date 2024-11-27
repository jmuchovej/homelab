{ config, pkgs, lib, ...  }: {
  sops.secrets.shared = {
    sopsFile   = ./secrets.sops.yaml;
    format     = "yaml";
    parseValue = true;
  };
}
