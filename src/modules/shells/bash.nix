{
  rbn.shells._.bash = {
    os = { pkgs, ... }: {
      environment.shells = [ pkgs.bash ];
    };

    hm = { pkgs, ... }: {
      home.shell.enableBashIntegration = true;
      programs.bash = {
        enable = true;
        enableCompletion = true;

        historyControl = [ "ignoredups" ];
        historyFileSize = 100000;

        shellOptions = [
          "autocd"
          "histappend"
          "direxpand"
          "checkwinsize"
          "extglob"
          "globstar"
          "checkjobs"
        ];
      };

      home.packages = with pkgs; [ nix-bash-completions ];
    };
  };
}
