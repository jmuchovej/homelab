{
  rbn.programs._.development._.powershell = {
    hm-linux = { pkgs, ... }: {
      home.packages = [ pkgs.powershell ];
    };

    macos.homebrew.casks = [ "powershell" ];
  };
}
