_: {
  rbn.shells._.bash.homeManager =
    { pkgs, ... }:
    {
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

      home.packages = with pkgs; [
        nix-bash-completions
      ];
    };
}
