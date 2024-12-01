{ config, pkgs, lib, ...  }: {
  environment.systemPackages = [
    pkgs.zfs
    pkgs.nfs-utils
  ];

  boot.zfs = {
    # enabled           = true;
    allowHibernation  = false;
    forceImportAll    = true;
  };

  services.zfs = {
    autoSnapshot = {
      flags     = "-k -p";
      enable    = true;
      frequent  = 12;
      daily     = 10;
      weekly    =  7;
      hourly    = 48;
      monthly   = 24;
    };

    autoScrub = {
      enable    = true;
      interval  = "monthly";
    };

    trim = {
      enable              = true;
      interval            = "daily";
      randomizedDelaySec  = "4h";
    };
  };
}
