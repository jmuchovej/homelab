{ config, lib, pkgs, ... }: {
  environment.systemPackages = [ pkgs.sssd ];

  sops.secrets.ldap.sopsFile = ./ldap.sops.yaml;

  services.nscd.enableNsncd = true;

  # Get sudoer data from sssd
  system.nssDatabases = {
    sudoers = ["sss"];
  };

  # Make sure `sudo` supports SSSD
  security.sudo.package = pkgs.sudo.override { withSssd = true; };

  # Configure some "autohomedir" things for PAM
  security.pam.services = {
    sshd = {
      makeHomeDir = true;
      sssdStrictAccess = true;
      unixAuth = lib.mkForce true;
    };
    login = {
      makeHomeDir = true;
      sssdStrictAccess = true;
      unixAuth = lib.mkForce true;
    };
  };

  services.sssd = {
    enable = true;
    sshAuthorizedKeysIntegration = true;
    environmentFile = config.sops.secrets.ldap.path;
    config = ''
      [nss]
      filter_groups         = root
      filter_users          = root,lab
      reconnection_retries  = 3

      [sssd]
      config_file_version   = 2
      reconnection_retries  = 3
      services              = nss, pam, ssh, sudo
      domains               = my-domain

      [pam]
      reconnection_retries            = 3
      offline_credentials_expiration  = 30

      [sudo]
      # don't need anything here; but otherwise sssd doesn't create the sudo config

      [domain/my-domain]
      enumerate                 = true
      cache_credentials         = true
      auto_private_groups       = true

      id_provider               = ldap
      chpass_provider           = ldap
      auth_provider             = ldap
      access_provider           = ldap
      sudo_provider             = ldap

      ldap_uri                  = $LDAP_URI
      ldap_schema               = rfc2307bis
      ldap_search_base          = $LDAP_SEARCH_BASE
      ldap_user_search_base     = $LDAP_SEARCH_USER
      ldap_sudo_search_base     = $LDAP_SEARCH_SUDO
      ldap_group_search_base    = $LDAP_SEARCH_GROUPS

      ldap_user_object_class    = user
      ldap_user_name            = cn
      fallback_homedir          = /home/%u
      ldap_user_home_directory  = /home/%u
      ldap_user_shell           = /run/current-system/sw/bin/zsh
      default_shell             = /run/current-system/sw/bin/zsh
      ldap_group_object_class   = group
      ldap_group_name           = cn
      ldap_group_uuid           = uid

      ldap_access_order         = filter
      ldap_access_filter        = $LDAP_ACCESS_FILTER

      ldap_default_bind_dn      = $LDAP_DEFAULT_BIND_DN
      ldap_default_authtok      = $LDAP_DEFAULT_AUTHTOK
      ldap_default_authtok_type = password

      # ldap_tls_cacert           = $LDAP_TLS_CACERT
      ldap_tls_reqcert          = allow
      ldap_id_use_start_tls     = true
    '';
  };
}
