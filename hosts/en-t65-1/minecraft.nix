{ config, lib, pkgs, ... }: {
  sops.secrets.minecraft-family.sopsFile = ./secrets.sops.yaml;

  virtualisation.oci-containers.containers = {
    minecraft-family = {
      image = "docker.io/itzg/minecraft-server:latest";
      autoStart = true;
      ports = [ "0.0.0.0:11895:25565" ];
      hostname = "minecraft-family";
      environmentFiles = [
        config.sops.secrets.minecraft-family.path
      ];
      environment = {
        EULA              = "true";
        GID               = "60";
        MEMORY            = "12G";
        FORCE_REDOWNLOAD  = "true";
        VERSION           = "1.19.2";
        TYPE              = "FORGE";
        FORGE_VERSION     = "43.4.0";
        CURSEFORGE_FILES  = ''
        architectury-api
        biomes-o-plenty
        bookshelf
        clumps
        cofh-core
        enchantment-descriptions
        falling-tree
        framework
        inventory-hud-forge
        inventory-profiles-next
        jade
        jei
        kitchen-karrot
        kotlin-for-forge
        libipn
        macaws-bridges
        macaws-doors
        macaws-holidays
        macaws-lights-and-lamps
        macaws-roofs
        macaws-trapdoors
        macaws-windows
        mekanism
        mekanism-generators
        mekanism-tools
        refurbished-furniture
        second-inventory
        serene-seasons
        terrablender
        thermal-cultivation
        thermal-dynamics
        thermal-expansion
        thermal-foundation
        thermal-innovation
        thermal-integration
        thermal-locomotion
        when-dungeons-arise
        when-dungeons-arise-seven-seas
        xaeros-minimap
        xaeros-world-map
        '';
      };
      volumes = [
        "/impulse/Games/minecraft/family:/data:Z"
      ];
      labels = {};
    };
  };
}
