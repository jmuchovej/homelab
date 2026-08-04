{
  rbn.programs._.terminal._.ssh = {
    hm-macos = _: {
      programs.ssh.settings."Match Host * exec \"test -z $SSH_TTY\"" = {
        IdentityAgent = "~/.1password/agent.sock";
      };
    };

    hm =
      _:
      let
        default-per-host-ssh.ForwardAgent = "yes";
        default-per-host-ssh.IdentitiesOnly = "yes";
      in
      {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          includes = [ "config.d/*" ];
          settings = {
            "Host *" = {
              AddKeysToAgent = "no";
              Compression = "yes";
              ServerAliveInterval = 0;
              ServerAliveCountMax = 3;
              HashKnownHosts = "yes";
              UserKnownHostsFile = "~/.ssh/known_hosts";
              ControlMaster = "auto";
              ControlPath = "~/.ssh/master-%r@%n:%p";
              ControlPersist = "5m";
              IdentitiesOnly = "no";
            };
            "Host *.github.com" = default-per-host-ssh // {
              IdentityFile = "~/.ssh/1p-github.pub";
            };
            "Host *.gitlab.com" = default-per-host-ssh // {
              IdentityFile = "~/.ssh/1p-gitlab.pub";
            };
            "Host *.ycrc.yale.edu" = default-per-host-ssh // {
              IdentityFile = "~/.ssh/1p-yale-crc.pub";
            };
            "Host *.rc.fas.harvard.edu" = default-per-host-ssh // {
              IdentityFile = "~/.ssh/1p-harvard-fas-rc.pub";
            };
            "Host *.tailcab76.ts.net *.jm0.io" = default-per-host-ssh // {
              IdentityFile = "~/.ssh/1p-homelab.pub";
            };
            "Host *.holonet.jm0.io" = default-per-host-ssh // {
              IdentityFile = "~/.ssh/1p-admin@mikrotik.pub";
            };
          };
        };
      };
  };
}
