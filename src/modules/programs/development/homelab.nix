{
  rbn.programs._.development._.homelab.homeManager = { pkgs, ... }: {
    home.packages = [ pkgs.opentofu ];

    # https://zed.dev/docs/languages/terraform
    programs.zed-editor = {
      extensions = [ "opentofu" ];
      extraPackages = with pkgs; [
        opentofu
        tofu-ls
      ];
      userSettings = {
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
  };
}
