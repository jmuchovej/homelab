{ config, ... }: {
  sops.secrets.zerotierone = {
    sopsFile   = ./zerotier.sops.yaml;
    format     = "yaml";
    parseValue = true;
  };

  services.zerotierone = {
    enable        = true;
    joinNetworks  = config.sops.secrets.zerotierone.networks;
  };
}
