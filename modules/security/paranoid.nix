# Security lockdown mode — not currently included by any host.
_: {
  rbn.security._.paranoid.nixos =
    { lib, pkgs, ... }:
    {
      nix.allowedUsers = [ "@wheel" ];
      environment.defaultPackages = lib.mkForce [ ];

      services.openssh = {
        passwordAuthentication = false;
        allowSFTP = false;
        challengeResponseAuthentication = false;
        extraConfig = ''
          AllowTcpForwarding yes
          X11Forwarding no
          AllowAgentForwarding no
          AllowStreamLocalForwarding no
          AuthenticationMethods publickey
        '';
      };

      fileSystems."/".options = [ "noexec" ];
      fileSystems."/etc/nixos".options = [ "noexec" ];
      fileSystems."/srv".options = [ "noexec" ];
      fileSystems."/var/log".options = [ "noexec" ];

      environment.systemPackages = [ pkgs.clamav ];
    };
}
