{ config, ... }: {
  services.zerotierone = {
    enable        = true;
    joinNetworks  = [
      "48d6023c4695358b"  # Homelab
      # "!!ZEROTIER_HOMELAB!!"
    ];
  };
}
