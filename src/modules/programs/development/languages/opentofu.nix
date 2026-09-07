{
  rbn.programs._.development._.languages._.opentofu.hm =
    { lib, pkgs, ... }:
    let
      # https://github.com/opentofu/tofu-ls/blob/main/docs/SETTINGS.md
      tofu-lsp = lib.rbn.mk-lsp {
        pkg = pkgs.tofu-ls;
        args = [ "serve" ];
        extensions = {
          ".tf" = "terraform";
          ".tofu" = "terraform";
          ".tfvars" = "terraform-vars";
          ".tofuvars" = "terraform-vars";
        };
        init = {
          experimentalFeatures = {
            validateOnSave = true;
            prefillRequiredFields = true;
          };
          validation.enableEnhancedValidation = true;
        };
      };
    in
    {
      home.packages = [ pkgs.opentofu ];

      # https://zed.dev/docs/languages/terraform
      programs.zed-editor = {
        extensions = [ "opentofu" ];
        extraPackages = [
          pkgs.opentofu
          tofu-lsp.pkg
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
          lsp.tofu-ls = tofu-lsp.zed;
          languages.OpenTofu = {
            tab_size = 2;
            formatter = "language_server";
            language_servers = [ "tofu-ls" ];
          };
        };
      };

      programs.claude-code.lspServers = {
        tofu = tofu-lsp.claude;
      };

      mcp-servers.settings.servers = {
        opentofu = {
          type = "streamable-http";
          url = "https://mcp.opentofu.org/mcp";
        };
      };
    };
}
