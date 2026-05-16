_: {
  rbn.programs._.terminal._.ssh.homeManager =
    { pkgs, ... }:
    let
      inherit (pkgs.stdenv) isDarwin;
    in
    {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        includes = [ "config.d/*" ];
        settings = {
          "Host *" = {
            ForwardAgent = isDarwin;
            AddKeysToAgent = "no";
            Compression = false;
            ServerAliveInterval = 0;
            ServerAliveCountMax = 3;
            HashKnownHosts = false;
            UserKnownHostsFile = "~/.ssh/known_hosts";
            ControlMaster = "no";
            ControlPath = "~/.ssh/master-%r@%n:%p";
            ControlPersist = "no";
            IdentitiesOnly = isDarwin;
            IdentityAgent = if isDarwin then "~/.1password/agent.sock" else null;
          };
        };
      };
    };
}
