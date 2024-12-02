{ config, lib, pkgs, ... }: {
  virtualisation.oci-containers.containers = {
    minecraft-family = {
      image = "docker.io/itzg/minecraft-server:latest";
      autoStart = true;
      ports = [ "0.0.0.0:11895:25565" ];
      hostname = "minecraft-family";
      environment = {
        EULA              = "TRUE";
        PGID              = "60";
        MEMORY            = "12G";
        FORCE_REDOWNLOAD  = "true";
        VERSION           = "1.19.2";
        TYPE              = "FORGE";
        FORGE_VERSION     = "43.4.0";
      };
      volumes = [
        "/impulse/Games/minecraft/family:/data"
      ];
      labels = {};
    };
  };
}
