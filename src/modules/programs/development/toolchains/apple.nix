{ __findFile, ... }: {
  rbn.programs._.development._.toolchains._.android = {
    includes = [
      <rbn/programs/development/languages/swift>
    ];

    macos = {
      brews = [
        "cocoapods"
        "xcodegen"
        "xcodes"
      ];
    };
  };
}
