{ __findFile, ... }: {
  rbn.programs._.development._.data._.json.hm = _: {
    programs.zed-editor = {
      userSettings = {
        file_types = {
          JSON = [
            "devenv.lock"
            "flake.lock"
          ];
        };
        languages = {
          "JSON" = {
            formatter = "none";
            language_servers = [ "json-language-server" ];
          };
          "JSONC" = {
            formatter = "none";
            language_servers = [ "json-language-server" ];
          };
        };
        lsp.json-language-server = {
          settings = { };
        };
      };
    };
  };
  rbn.programs._.development._.data._.jsonc = {
    includes = [ <rbn/programs/development/data/json> ];
  };
  rbn.programs._.development._.data._.json5.hm = _: {
    programs.zed-editor = {
      extensions = [ "json5" ];
      userSettings = {
        languages.JSON5 = {
          formatter = "none";
          language_servers = [ "json-language-server" ];
        };
      };
    };
  };
  rbn.programs._.development._.data._.jsonl.hm = _: {
    programs.zed-editor = {
      extensions = [
        "jsonl"
        # "jsonl-lsp"
      ];
      userSettings = {
        languages."JSON Lines" = { };
        # lsp.jsonl-lsp = { };
      };
    };
  };
  rbn.programs._.development._.data._.jsonnet.hm = _: {
    programs.zed-editor = {
      extensions = [ "jsonnet" ];
      userSettings = {
        languages.Jsonnet = {
          formatter = "none";
          language_servers = [ "jsonnet-language-server" ];
        };
        lsp.jsonnet-language-server = { };
      };
    };
  };
}
