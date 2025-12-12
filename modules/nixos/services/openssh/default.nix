{
  config,
  format,
  lib,
  namespace,
  ...
}:
let
  inherit (lib)
    types
    mkDefault
    mkIf
    mkEnableOption
    mkOption
    ;

  cfg = config.rebellion.services.openssh;

  default-key =  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID3FPLe1ZXSk7KBgSkJud2hlvUAGF5m57g2Pqpccy5SO lab@home.jm0.io";
in
{
  options.rebellion.services.openssh = with types; {
    enable = mkEnableOption "OpenSSH";
    authorized-keys = mkOption {
      type = listOf str;
      default = [ default-key ];
      description = "The public keys to apply.";
    };
    extra-config = mkOption {
      type = str;
      default = "";
      description = "Extra configuration to apply.";
    };
    port = mkOption {
      type = port;
      default = 2222;
      description = "The port to listen on (in addition to 22).";
    };
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;

      hostKeys = mkDefault [
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
        cfg.port
      ];

      settings = {
        AuthenticationMethods = "publickey";
        ChallengeResponseAuthentication = "no";
        PasswordAuthentication = false;
        PermitRootLogin = if format == "install-iso" then "yes" else "no";
        PubkeyAuthentication = "yes";
        StreamLocalBindUnlink = "yes";
        UseDns = false;
        UsePAM = true;
        X11Forwarding = false;

        # key exchange algorithms recommended by `nixpkgs#ssh-audit`
        KexAlgorithms = [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "diffie-hellman-group16-sha512"
          "diffie-hellman-group18-sha512"
          "diffie-hellman-group-exchange-sha256"
          "sntrup761x25519-sha512@openssh.com"
        ];

        # message authentication code algorithms recommended by `nixpkgs#ssh-audit`
        Macs = [
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
          "umac-128-etm@openssh.com"
        ];
      };

      # startWhenNeeded = true;
    };

    programs.ssh = {
      startAgent = lib.mkDefault true;
    };

    # environment.persist.files = [
    #   "/etc/machine-id"
    #   "/etc/ssh/ssh_host_ed25519_key"
    #   "/etc/ssh/ssh_host_ed25519_key.pub"
    #   "/etc/ssh/ssh_host_rsa_key"
    #   "/etc/ssh/ssh_host_ras_key.pub"
    # ];

    rebellion = {
      user.extra.options.openssh.authorizedKeys.keys = cfg.authorized-keys;

    #   home.extraOptions = {
    #     programs.zsh.shellAliases = foldl (
    #       aliases: system: aliases // { "ssh-${system}" = "ssh ${system} -t tmux a"; }
    #     ) { } (builtins.attrNames other-hosts);
    #   };
    };
  };
}
