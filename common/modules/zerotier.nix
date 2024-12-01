{ config, ... }: {
  sops.secrets."/var/lib/zerotier-one/networks.d/${}"
  services.zerotierone = {
    enable        = true;
    joinNetworks  = [
      "48d6023c4695358b"  # Homelab
      # "!!ZEROTIER_HOMELAB!!"
    ]
  };
}
