{
  inputs,
  self,
}:
let
  inherit (inputs.nixpkgs.lib)
    genAttrs
    filterAttrs
    hasPrefix
    hasSuffix
    filter
    foldl'
    ;

  get-nix-files' =
    path:
    let
      entries = builtins.readDir path;
    in
    filter (name: hasSuffix ".nix" name) (builtins.attrNames entries);

  merge-attrs' = attrs-ls: foldl' (acc: attrs: acc // attrs) { } attrs-ls;
in
{
  # Read a file and return its contents
  read-file = path: builtins.readFile path;

  # Check if a file exists
  path-exists = path: builtins.pathExists path;

  # Import a nix file with error handling
  # If path is a directory, will look for default.nix within it
  safe-import =
    path: default:
    let
      pathType = builtins.readFileType path;
      # If it's a directory, check for default.nix inside it
      actualPath = if pathType == "directory" then path + "/default.nix" else path;
    in
    if builtins.pathExists actualPath then import path else default;

  # Scan a directory and return directory names
  scan-dir = path: builtins.attrNames (builtins.readDir path);

  # Get a file path relative to the flake root (similar to Snowfall's get-file)
  get-file = relativePath: self + "/${relativePath}";

  # Get all .nix files from a directory
  # Returns a list of file names (without paths)
  # Usage: get-nix-files ./hooks
  get-nix-files = get-nix-files';

  # Import all .nix files from a directory
  # Returns a list of imported values
  # Usage: import-files ./hooks { inherit pkgs; }
  import-files =
    path: args:
    let
      nixFiles = get-nix-files' path;
    in
    map (name: import (path + "/${name}") args) nixFiles;

  # Import all .nix files from a directory and merge them into a single attribute set
  # Convenience function combining import-files and merge-attrs
  # Usage: import-dir ./hooks { inherit pkgs; }
  import-dir =
    path: args:
    let
      nix-files = get-nix-files' path;
      imported = map (name: import (path + "/${name}") args) nix-files;
    in
    merge-attrs' imported;

  # Import all .nix files from a directory without passing args
  # For files that are plain attribute sets (not functions)
  # Usage: import-dir-plain ./skills
  # Usage: import-dir-plain ./skills [ "default.nix" ]  # exclude specific files
  import-dir-plain =
    {
      path,
      exclude ? [ ],
    }:
    let
      exclude-list = if builtins.isList exclude then exclude else [ ];
      nix-files = filter (name: !(builtins.elem name exclude-list)) (get-nix-files' path);
    in
    merge-attrs' (map (name: import (path + "/${name}")) nix-files);

  # Import all .nix files from all subdirectories, merging results
  # Useful for organizing related files in subdirs (e.g., skills/nix/, skills/git/)
  # Usage: import-subdirs ./skills { exclude = [ "default.nix" ]; }
  # Usage: import-subdirs ./commands { args = { inherit lib; }; }  # with args
  import-subdirs =
    path:
    {
      exclude ? [ ],
      args ? null,
    }:
    let
      entries = builtins.readDir path;
      subdirs = filter (name: entries.${name} == "directory") (builtins.attrNames entries);
      import-subdir =
        dir:
        let
          dirPath = path + "/${dir}";
          files = filter (f: !(builtins.elem f exclude)) (get-nix-files' dirPath);
          import-file =
            f: if args == null then import (dirPath + "/${f}") else import (dirPath + "/${f}") args;
        in
        merge-attrs' (map import-file files);
    in
    merge-attrs' (map import-subdir subdirs);

  # Recursively discover and import all Nix modules in a directory tree
  import-modules-recursive =
    path:
    {
      exclude ? ".*\\.part\\.nix$",
    }:
    let
      # helper to check if filename matches exclusion pattern
      should-exclude = name: builtins.match exclude name != null;

      # Helper function to recursively walk directories
      walk-dir =
        current-path:
        let
          current-entries = builtins.readDir current-path;
          entry-names = builtins.attrNames current-entries;

          nix-files = builtins.filter (
            name: current-entries.${name} == "regular" && hasSuffix ".nix" name && !should-exclude name
          ) entry-names;

          # Get ALL directories (to recurse into)
          all-directories = builtins.filter (name: current-entries.${name} == "directory") entry-names;

          # Import directories that have default.nix
          file-imports = map (name: current-path + "/${name}") nix-files;

          # Recursively walk ALL subdirectories
          subdir-imports = builtins.concatLists (
            map (dir: walk-dir (current-path + "/${dir}")) all-directories
          );

        in
        file-imports ++ subdir-imports;

    in
    walk-dir path;

  # Recursively parse systems directory structure
  parse-system-configurations =
    systemsPath:
    let
      entries = builtins.readDir systemsPath;
      systemArchs = filter (name: entries.${name} == "directory") (builtins.attrNames entries);

      generate-system-configs =
        system:
        let
          systemPath = systemsPath + "/${system}";
          hosts = builtins.attrNames (builtins.readDir systemPath);
        in
        genAttrs hosts (hostname: {
          inherit system hostname;
          path = systemPath + "/${hostname}";
        });
    in
    foldl' (acc: system: acc // generate-system-configs system) { } systemArchs;

  # Filter systems for NixOS
  filter-nixos-systems =
    systems:
    filterAttrs (
      _name: { system, ... }: hasPrefix "x86_64-linux" system || hasPrefix "aarch64-linux" system
    ) systems;

  # Filter systems for macOS
  filter-macos-systems =
    systems:
    filterAttrs (
      _name: { system, ... }: hasPrefix "aarch64-darwin" system || hasPrefix "x86_64-darwin" system
    ) systems;

  # Parse homes directory structure for home configurations
  parse-home-configurations =
    homes-path:
    let
      entries = builtins.readDir homes-path;
      sys-arches = filter (name: entries.${name} == "directory") (builtins.attrNames entries);

      generate-home-configs =
        system:
        let
          system-path = homes-path + "/${system}";
          user-dirs = builtins.attrNames (builtins.readDir system-path);

          parse-user-dir =
            user-dir:
            let
              has-host = builtins.match "[^@]+@[^@]+" user-dir != null;
              parts =
                if has-host then
                  builtins.split "@" user-dir
                else
                  [
                    user-dir
                    null
                  ];
              username = builtins.elemAt parts 0;
              hostname = builtins.elemAt parts 1;
            in
            {
              inherit
                system
                username
                hostname
                user-dir
                ;
              key = user-dir;
              path = system-path + "/${user-dir}";
            };
        in
        genAttrs user-dirs parse-user-dir;
    in
    foldl' (acc: system: acc // generate-home-configs system) { } sys-arches;
}
