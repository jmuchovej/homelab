{ __findFile, ... }: {
  rbn.programs._.development._.data._.xml.hm = _: {
    programs.zed-editor = {
      extensions = [ "xml" ];
      userSettings = {
        file_types.XML = [
          "*.svg"
          "*.xsl"
        ];
        languages.XML = { };
      };
    };
  };
}
