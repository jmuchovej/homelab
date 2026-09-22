{ __findFile, den, ... }: {
  rbn.programs._.development._.toolchains._.android = {
    includes = [
      (den.batteries.unfree [ "android-studio" ])
      <rbn/programs/development/languages/kotlin>
    ];

    hm-linux = { pkgs, ... }: {
      home.packages = [ pkgs.android-studio ];
    };

    macos = {
      homebrew.casks = [ "android-studio" ];
    };
  };
}
