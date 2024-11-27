{ config, pkgs, lib, ...  }: {
  imports = [ <sops-nix/modules/sops> ];

  sops.secrets.shared = {
    sopsFile   = ./secrets.sops.yaml;
    format     = "yaml";
    parseValue = true;
  };
}
