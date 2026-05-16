{ inputs, ... }:
{
  rbn.services._.zerotier = {
    nixos =
      {
        host,
        config,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (lib) mkMerge;
        inherit (lib.rbn) get-secret;

        topology = lib.rbn.from-yaml (inputs.self + "/src/topology.yaml") { inherit pkgs; };
        network = topology.zerotier.network;

        identity-key = "zerotier/secret-key";

        state-dir = "/var/lib/zerotier-one";
        identity = "${state-dir}/identity.secret";
        identity-id = config.sops.secrets.${identity-key}.path;
      in
      mkMerge [
        (get-secret config identity-key "hosts/${host.hostname}")
        {
          sops.secrets.${identity-key} = {
            owner = "root";
            mode = "0400";
            restartUnits = [ "zerotierone.service" ];
          };

          services.zerotierone = {
            enable = true;
            joinNetworks = [ network ];
          };

          networking.firewall.trustedInterfaces = [ "zt+" ];

          systemd.services.zerotierone.preStart = ''
            install -d -m 0700 ${state-dir}
            if [ ! -f ${identity} ]; then
              install -m 0400 ${identity-id} ${identity}
              ${pkgs.zerotierone}/bin/zerotier-idtool getpublic ${identity} \
                > ${state-dir}/identity.public
              chmod 0644 ${state-dir}/identity.public
            fi
          '';
        }
      ];

    darwin =
      {
        host,
        config,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (lib) mkMerge;
        inherit (lib.rbn) get-secret;

        topology = lib.rbn.from-yaml (inputs.self + "/src/topology.yaml") { inherit pkgs; };
        network = topology.zerotier.network;

        identity-key = "zerotier/secret-key";
        identity-src = config.sops.secrets.${identity-key}.path;

        # ZeroTier's macOS home — where the official daemon reads identity/joins.
        home = "/Library/Application Support/ZeroTier/One";
      in
      mkMerge [
        (get-secret config identity-key "hosts/${host.hostname}")
        {
          sops.secrets.${identity-key} = {
            owner = "root";
            mode = "0400";
          };

          homebrew.casks = lib.mkIf host.homebrew.enable [ "zerotier-one" ];

          environment.systemPackages = [ pkgs.zerotierone ]; # zerotier-cli on PATH

          system.activationScripts.zerotier-identity.text = ''
            home="${home}"
            mkdir -p "$home/networks.d"
            if [ ! -f "$home/identity.secret" ] && [ -f "${identity-src}" ]; then
              install -m 0600 "${identity-src}" "$home/identity.secret"
              ${pkgs.zerotierone}/bin/zerotier-idtool getpublic "$home/identity.secret" \
                > "$home/identity.public"
            fi
            : > "$home/networks.d/${network}.conf"
          '';
        }
      ];
  };
}
