{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "services.qbittorrent";
  config =
    {
      config,
      lib,
      pkgs,
      hostname,
      datacenter,
      ...
    }:
    let
      inherit (lib) getExe';
      inherit (lib.rebellion) get-file;

      usr = config.services.qbittorrent.user;
      grp = config.services.qbittorrent.group;
    in
    lib.mkMerge [
      {
        rebellion.services.proton-vpn.enable = true;

        sops.secrets."qbittorrent/username" = {
          sopsFile = get-file "secrets/secrets.sops.yaml";
          owner = usr;
          group = grp;
        };
        sops.secrets."qbittorrent/password" = {
          sopsFile = get-file "secrets/secrets.sops.yaml";
          owner = usr;
          group = grp;
        };

        services.qbittorrent = {
          enable = true;
          openFirewall = true;
          webuiPort = 9797;
          serverConfig = {
            Preferences.WebUI = {
              Address = "*";
              AlternativeUIEnabled = true;
              RootFolder = "${pkgs.vuetorrent}/share/vuetorrent";
            };
            BitTorrent.Session = {
              Interface = "proton0";
              InterfaceName = "proton0";
            };
            LegalNotice.Accepted = true;
          };
        };

        systemd.services.qbittorrent =
          let
            crudini = getExe' pkgs.crudini "crudini";
            python = getExe' pkgs.python3 "python";
            qb = config.services.qbittorrent;
            # Inject secrets into qBittorrent config at runtime
            pre-start = pkgs.writeShellScript "qbittorrent-inject-secrets" ''
              # Read secrets from sops-nix
              USERNAME=$(cat ${config.sops.secrets."qbittorrent/username".path})
              PASSWORD=$(cat ${config.sops.secrets."qbittorrent/password".path})

              # Generate PBKDF2 hash for qBittorrent
              # Format: @ByteArray(salt:hash)
              HASH=$(${python} -c "
              import hashlib
              import os
              import base64

              password = '$PASSWORD'
              salt = os.urandom(16)
              iterations = 100_000
              algorithm = 'sha512'

              dk = hashlib.pbkdf2_hmac(algorithm, password.encode(), salt, iterations)

              encoded_salt = base64.b64encode(salt).decode()
              encoded_hash = base64.b64encode(dk).decode()

              print(f'@ByteArray({encoded_salt}:{encoded_hash})')
              ")

              CONFIG_FILE="${qb.profileDir}/qBittorrent/config/qBittorrent.conf"
              mkdir -p "$(dirname "$CONFIG_FILE")"
              touch "$CONFIG_FILE"
              chown -R ${qb.user}:${qb.group} ${qb.profileDir}

              # Update config file using crudini
              ${crudini} --set "$CONFIG_FILE" "Preferences" "WebUI\\Username" "$USERNAME"
              ${crudini} --set "$CONFIG_FILE" "Preferences" "WebUI\\Password_PBKDF2" "\"$HASH\""
              chown -R ${qb.user}:${qb.group} "$CONFIG_FILE"
            '';
          in
          {
            serviceConfig.SupplementaryGroups = [ "proton" ];
            serviceConfig.ExecStartPre = lib.mkAfter [ "+${pre-start} " ];
          };
      }

      (
        let
          inherit (lib.rebellion) merge-attrs;
          inherit (lib.rebellion.network) with-consul mk-traefik-service mk-healthcheck;
          service = merge-attrs [
            (mk-traefik-service {
              inherit hostname datacenter;
              name = "qbittorrent";
              port = config.services.qbittorrent.webuiPort;
              public = true;
            })
            {
              svc.config.loadBalancer.passHostHeader = false;
            }
          ];
          healthcheck = mk-healthcheck service {
            route = "/"; # Root path doesn't require auth
          };
        in
        with-consul config (service // { checks = [ healthcheck ]; })
      )
    ];
}
