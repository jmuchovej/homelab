{ __findFile, ... }:
{
  rbn.programs._.development._.data._.csv.hm = _: {
    programs.zed-editor = {
      extensions = [ "rainbow-csv" ];
      userSettings = {
        languages = {
          "Rainbow TSV (⭲)" = { };
          "Rainbow CSV (,)" = { };
          "Rainbow CSV (;)" = { };
          "Rainbow CSV (|)" = { };
        };
      };
    };
  };

  rbn.programs._.development._.data._.tsv = {
    includes = [ <rbn/programs/development/data/csv> ];
  };
}
