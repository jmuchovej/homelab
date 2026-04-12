_: {
  rbn.programs._.development._.homelab.homeManager =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkIf;
      inherit (lib.rebellion.zed) mk-zed-settings;

      # https://zed.dev/docs/languages/go
      zed = mk-zed-settings {
        extensions = [
          "opentofu"
        ];
        packages = with pkgs; [
          opentofu
          tofu-ls
        ];
        settings = {
          file_types = {
            OpenTofu = [
              "tf"
              "tofu"
            ];
            "OpenTofu Vars" = [
              "tfvars"
              "tofuvars"
            ];
          };
          lsp.tofu-ls = {
            indexing = {
              ignorePaths = [ ];
              ignoreDirectoryNames = [
                ".scratch"
                ".arxiv"
              ];
            };
            # https://github.com/opentofu/tofu-ls/blob/main/docs/SETTINGS.md
            initialization_options = {
              experimentalFeatures = {
                validateOnSave = true;
                prefillRequiredFields = true;
              };
              validation.enableEnhancedValidation = true;
            };
          };
          languages.OpenTofu = {
            tab_size = 2;
            language_servers = [ "tofu-ls" ];
          };
        };
      };
    in
    {
      home.packages = zed.extraPackages;

      programs.zed-editor = mkIf (config.programs.zed-editor.enable or false) {
        inherit (zed) extensions extraPackages userSettings;
      };
    };
}
