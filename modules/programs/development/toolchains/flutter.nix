{ __findFile, ... }:
{
  rbn.programs._.development._.toolchains._.flutter = {
    includes = [ <rbn/programs/development/languages/dart> ];

    hm = { pkgs, ... }: {
      programs.vscode = {
        profiles.default.extensions = with pkgs.open-vsx; [
          dart-code.flutter
        ];
        profiles.default.userSettings = { };
      };
    };
  };
}
