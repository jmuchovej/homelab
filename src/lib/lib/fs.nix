{
  lib,
  rebellion-lib,
  inputs,
}:
let
  inherit (lib)
    concatLists
    hasSuffix
    optionals
    removeSuffix
    ;
  inherit (builtins)
    attrNames
    filter
    match
    pathExists
    readDir
    readFile
    readFileType
    elem
    isList
    ;
  inherit (rebellion-lib) path;
  inherit (rebellion-lib.attrs) merge-shallow;
in
{
  fs = rec {
    ## Matchers for file kinds. These are often used with `readDir`.
    ## Example Usage:
    ## ```nix
    ## is-file-kind "directory"
    ## ```
    ## Result:
    ## ```nix
    ## false
    ## ```
    #@ String -> Bool
    is-file-kind = kind: kind == "regular";
    is-symlink-kind = kind: kind == "symlink";
    is-directory-kind = kind: kind == "directory";
    is-unknown-kind = kind: kind == "unknown";

    # -------------------------------------------------------------------------
    # Core primitive: recursive file walker
    # -------------------------------------------------------------------------

    ## Walk a directory tree, collecting files matching criteria.
    ##   suffix:  only include files ending with this (default ".nix")
    ##   exclude: regex to exclude file names (default: null)
    ##   depth:   0 = current dir only, 1 = +immediate subdirs, -1 = unlimited
    #@ { suffix?, exclude?, depth? } -> Path -> [Path]
    walk-files =
      {
        suffix ? ".nix",
        exclude ? null,
        depth ? -1,
      }:
      path:
      let
        should-exclude = name: if exclude == null then false else match exclude name != null;
        walk =
          current: level:
          let
            entries = readDir current;
            names = attrNames entries;
            files = filter (n: entries.${n} == "regular" && hasSuffix suffix n && !should-exclude n) names;
            dirs = filter (n: entries.${n} == "directory") names;
            recurse = depth == -1 || level < depth;
          in
          (map (n: current + "/${n}") files)
          ++ optionals recurse (concatLists (map (d: walk (current + "/${d}") (level + 1)) dirs));
      in
      walk path 0;

    get-module-files =
      path:
      walk-files {
        suffix = ".nix";
        depth = 0;
        exclude = ".*\\.part\\.nix$";
      } path;

    get-module-files' =
      path:
      walk-files {
        suffix = ".nix";
        depth = -1;
        exclude = ".*\\.part\\.nix$";
      } path;

    # -------------------------------------------------------------------------
    # Convenience helpers built on walk-files
    # -------------------------------------------------------------------------

    ## Safely read a directory; returns {} if path does not exist.
    #@ Path -> Attrs
    safe-read-directory = path: if pathExists path then readDir path else { };

    ## Get a file path relative to the flake root.
    #@ String -> Path
    get-file = path: "${inputs.self}/${path}";

    ## Get all files (any type) in a directory (non-recursive).
    #@ Path -> [Path]
    get-files =
      path:
      let
        entries = safe-read-directory path;
        names = filter (n: entries.${n} == "regular") (attrNames entries);
      in
      map (n: "${path}/${n}") names;

    ## Get all directories in a path (non-recursive).
    #@ Path -> [Path]
    get-directories =
      path:
      let
        entries = safe-read-directory path;
        names = filter (n: entries.${n} == "directory") (attrNames entries);
      in
      map (n: "${path}/${n}") names;

    ## Get all files recursively.
    #@ Path -> [Path]
    get-files-recursive = walk-files { suffix = ""; };

    ## Get all *.nix files in a directory (non-recursive).
    #@ Path -> [Path]
    get-nix-files = dir: filter (path.has-file-extension "nix") (get-files dir);

    ## Get all *.nix files recursively.
    #@ Path -> [Path]
    get-nix-files-recursive = walk-files { };

    ## Discover NixOS/HM modules: all *.nix files recursively, excluding *.part.nix.
    #@ Path -> [Path]
    discover-modules = walk-files { exclude = ".*\\.part\\.nix$"; };

    ## Load a file: .nix files are imported, everything else is read as text.
    #@ Path -> a -> a
    load-file =
      path: args:
      if hasSuffix ".nix" (toString path) then
        if args == null then import path else import path args
      else
        readFile path;

    ## Get the secret's path with the target filepath.
    #@ Config -> String -> String -> Attrs
    get-secret = _config: secret: filepath: {
      sops.secrets."${secret}" = {
        sopsFile = get-file "secrets/${filepath}.sops.yaml";
      };
    };

    ## Create a sops secret definition for a given secret name and filepath.
    #@ String -> String -> Attrs
    load-secret = secret: filepath: {
      sops.secrets."${secret}" = {
        sopsFile = get-secret filepath;
      };
    };

    ## Create a sops secret definition using the default "secrets" file.
    #@ Config -> String -> Attrs
    get-secret' = config: secret: get-secret config secret "secrets";

    ## Create a sops secret definition using the default "secrets" file.
    #@ String -> Attrs
    load-secret' = secret: load-secret secret "secrets";

    ## Get the module-path by name to load
    #@ String -> String
    get-module = platform: filepath: get-file "modules/${platform}/${filepath}.nix";

    ## Check if a path exists.
    #@ Path -> Bool
    path-exists = pathExists;

    ## Get the type of a file: "regular", "directory", "symlink", "unknown".
    #@ Path -> String
    file-type = readFileType;

    ## Check if a path is a directory.
    #@ Path -> Bool
    is-dir = path: (readFileType path) == "directory";

    ## Import a nix file with fallback default. If path is a directory, looks for default.nix.
    #@ Path -> a -> a
    safe-import =
      path: default:
      let
        real-path = if is-dir path then path + "/default.nix" else path;
      in
      if pathExists real-path then load-file real-path null else default;

    ## Get a file name without its .nix extension.
    #@ Path -> String
    stem = path: removeSuffix ".nix" (baseNameOf path);

    ## Scan a directory and return its entry names.
    #@ Path -> [String]
    scan-dir = path: attrNames (readDir path);

    ## Import all .nix files from a directory, returning a list of results.
    #@ Path -> Args -> [a]
    import-files = path: args: map (f: load-file f args) (get-nix-files path);

    ## Import all .nix files from a directory and merge into a single attrset.
    #@ Path -> Args -> Attrs
    import-dir = path: args: merge-shallow (import-files path args);

    ## Import all .nix files from a directory without passing args.
    #@ { path, exclude? } -> Attrs
    import-dir-plain =
      {
        path,
        exclude ? [ ],
      }:
      let
        exclude-list = if isList exclude then exclude else [ ];
        files = filter (f: !(elem (baseNameOf f) exclude-list)) (get-nix-files path);
      in
      merge-shallow (map (f: load-file f null) files);

    ## Import all .nix and .md files from subdirectories (depth 1), merging results.
    ## .nix files are imported normally (must return attrsets).
    ## .md files are loaded as { stem = content; } where stem is the filename without extension.
    #@ Path -> { exclude?, args? } -> Attrs
    import-subdirs =
      path:
      {
        exclude ? [ ],
        args ? null,
      }:
      let
        nix-files = walk-files { depth = 1; } path;
        md-files = walk-files {
          suffix = ".md";
          depth = 1;
        } path;
        all-files = nix-files ++ md-files;
        filtered = filter (f: !(elem (baseNameOf f) exclude)) all-files;
        load =
          f:
          if hasSuffix ".md" (toString f) then
            { ${removeSuffix ".md" (baseNameOf f)} = readFile f; }
          else
            load-file f args;
      in
      merge-shallow (map load filtered);

    ## Discover flake-parts partitions from a directory.
    ## Each subdirectory is a partition; expects <name>.partition.nix as the module.
    ## If a flake.nix exists in the subdir, it's used as extraInputsFlake.
    ## Uses path concatenation (not string interpolation) to preserve Nix path types,
    ## which is required for flake-parts extraInputsFlake.
    #@ Path -> [{ name, module, extraInputsFlake }]
    discover-partitions =
      path:
      let
        entries = safe-read-directory path;
        dir-names = filter (n: entries.${n} == "directory") (attrNames entries);
      in
      map (
        name:
        let
          dir = path + "/${name}";
        in
        {
          inherit name;
          module = dir + "/${name}.partition.nix";
          extraInputsFlake = if pathExists (dir + "/flake.nix") then dir else null;
        }
      ) dir-names;
  };
}
