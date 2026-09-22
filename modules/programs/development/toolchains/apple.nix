{ __findFile, ... }: {
  rbn.programs._.development._.toolchains._.apple = {
    includes = [
      <rbn/programs/development/languages/swift>
    ];

    macos = {
      homebrew.brews = [
        "cocoapods"
        "xcodegen"
        "xcodes"
      ];
    };
  };
}
