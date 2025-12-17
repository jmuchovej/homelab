[
  {
    file_types = {
      "JSONC" = [
        "**/.zed/**/*.json"
        "**/zed/**/*.json"
        "**/Zed/**/*.json"
        "**/.vscode/**/*.json"
      ];
      "Shell Script" = [
        ".env*"
      ];
    };

    # https://zed.dev/docs/configuring-zed#edit-predictions
    edit_predictions.disabled_globs = [
      "**/.env*"
      "**/*.pem"
      "**/*.key"
      "**/*.cert"
      "**/*.crt"
      "**/*.sops.yaml"
    ];

    # https://zed.dev/docs/configuring-zed#private-files
    private_files = [
      "**/.env*"
      "**/*.pem"
      "**/*.key"
      "**/*.cert"
      "**/*.crt"
      "**/*.sops.yaml"
    ];

    file_scan_inclusions = [ ];
    file_scan_exclusions = [
      "**/.git"
      "**/.svn"
      "**/.hg"
      "**/.jj"
      "**/CVS"
      "**/.DS_Store"
      "**/Thumbs.db"
      "**/.classpath"
      "**/.settings"
      "**/.sync-conflict*"
      "**/*.sync-conflict*"
    ];
  }

]
