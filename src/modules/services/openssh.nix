{ inputs, ... }: {
  rbn.services._.openssh = {
    # Shared across NixOS and nix-darwin: trust every fleet host's SSH key,
    # eliminating TOFU between nodes. Sourced from `secrets/systems/<host>.pub`;
    # entries without a pub file (e.g. `minimal`) are skipped by `systems-ssh`.
    os =
      { lib, ... }:
      let
        secrets-keys = import "${inputs.self}/secrets" { inherit lib; };
      in
      {
        programs.ssh.knownHosts = lib.mapAttrs (_: pub: { publicKey = pub; }) secrets-keys.systems-ssh;
      };

    nixos = { lib, ... }: {
      services.openssh = {
        enable = true;

        hostKeys = lib.mkDefault [
          {
            bits = 4096;
            path = "/etc/ssh/ssh_host_rsa_key";
            type = "rsa";
          }
          {
            bits = 4096;
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];

        openFirewall = true;
        ports = [
          22
        ];

        settings = {
          AuthenticationMethods = "publickey";
          ChallengeResponseAuthentication = "no";
          PasswordAuthentication = false;
          PermitRootLogin = "no";
          PubkeyAuthentication = "yes";
          StreamLocalBindUnlink = "yes";
          UseDns = false;
          UsePAM = true;
          X11Forwarding = false;

          KexAlgorithms = [
            "curve25519-sha256"
            "curve25519-sha256@libssh.org"
            "diffie-hellman-group16-sha512"
            "diffie-hellman-group18-sha512"
            "diffie-hellman-group-exchange-sha256"
            "sntrup761x25519-sha512@openssh.com"
          ];

          Macs = [
            "hmac-sha2-512-etm@openssh.com"
            "hmac-sha2-256-etm@openssh.com"
            "umac-128-etm@openssh.com"
          ];
        };
      };

      programs.ssh.startAgent = lib.mkDefault true;

      users.users.root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3FPLe1ZXSk7KBgSkJud2hlvUAGF5m57g2Pqpccy5SO lab@home.jm0.io"
      ];
    };
  };
}
