{ lib, pkgs, ... }@args:
lib.rebellion.mk-module args {
  name = "security.gpg";
  options =
    { lib, ... }:
    {
      agentTimeout =
        lib.rebellion.mk' lib.types.int 5
          "The amount of time to wait before continuing with shell init.";
    };
  config =
    {
      cfg,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (builtins) toString;

      gpgAgentConf = ''
        enable-ssh-support
        default-cache-ttl 60
        max-cache-ttl 120
      '';

      gpgconf-bin = lib.getExe' pkgs.gnupg "gpgpconf";
      timeout-bin = lib.getExe' pkgs.coreutils "timeout";
    in
    {
      environment.systemPackages = [ pkgs.gnupg ];

      environment.shellInit = ''
        export GPG_TTY="$(tty)"
        export SSH_AUTH_SOCK=$(${gpgconf-bin} --list-dirs agent-ssh-socket)

        ${timeout-bin} ${toString cfg.agentTimeout} ${gpgconf-bin} --launch gpg-agent
        gpg_agent_timeout_status=$?

        if [ "$gpg_agent_timeout_status" = 124 ]; then
          # Command timed out...
          echo "GPG Agent timed out..."
          echo 'Run "gpgconf --launch gpg-agent" to try and launch it again.'
        fi
      '';

      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };

      rebellion.home.file = {
        ".gnupg/.keep".text = "";
        ".gnupg/gpg-agent.conf".text = gpgAgentConf;
      };
    };
}
