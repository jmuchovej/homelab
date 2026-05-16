## Filesystem helpers: directory walkers and content composition.
##
##   import-dir     — import all `*.nix` files in a directory, merge into one attrset
##   import-subdirs — same, but recurses one level; also reads `*.md` files as
##                    `{ <stem> = <raw contents>; }`. Used by Zed settings
##                    composition and AI-tools agent/command loading.
{ lib, ... }:
let
  inherit (lib)
    concatLists
    hasSuffix
    optionals
    removeSuffix
    ;
  inherit (builtins)
    attrNames
    elem
    filter
    foldl'
    match
    pathExists
    readDir
    readFile
    ;

  merge-shallow = foldl' (a: b: a // b) { };

  safe-read-directory = path: if pathExists path then readDir path else { };

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

  get-files =
    path:
    let
      entries = safe-read-directory path;
      names = filter (n: entries.${n} == "regular") (attrNames entries);
    in
    map (n: "${path}/${n}") names;

  get-nix-files = dir: filter (hasSuffix ".nix") (get-files dir);

  load-file =
    path: args:
    if hasSuffix ".nix" (toString path) then
      if args == null then import path else import path args
    else
      readFile path;

  import-files = path: args: map (f: load-file f args) (get-nix-files path);

  import-dir = path: args: merge-shallow (import-files path args);

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

  from-yaml =
    file:
    { pkgs, ... }:
    builtins.fromJSON (
      builtins.readFile (
        pkgs.runCommand (baseNameOf file) { } ''
          ${pkgs.yq}/bin/yq < ${file} > $out
        ''
      )
    );
in
{
  _rbn-lib = {
    inherit import-dir import-subdirs from-yaml;
  };
}
