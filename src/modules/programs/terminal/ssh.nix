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
        matchBlocks = {
          "*" = {
            forwardAgent = isDarwin;
            addKeysToAgent = "no";
            compression = false;
            serverAliveInterval = 0;
            serverAliveCountMax = 3;
            hashKnownHosts = false;
            userKnownHostsFile = "~/.ssh/known_hosts";
            controlMaster = "no";
            controlPath = "~/.ssh/master-%r@%n:%p";
            controlPersist = "no";
            identitiesOnly = isDarwin;
            identityAgent = if isDarwin then "~/.1password/agent.sock" else null;
          };
        };
      };
    };
}
