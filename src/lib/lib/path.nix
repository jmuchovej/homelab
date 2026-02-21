{
  lib,
  ...
}:
let
  inherit (builtins)
    concatStringsSep
    match
    ;
  inherit (lib) assertMsg last init;

  file-name-regex = "(.*)\\.(.*)$";
in
{
  path = rec {
    ## Split a file name into [name extension].
    #@ String -> [String]
    split-file-extension =
      file:
      let
        m = match file-name-regex file;
      in
      assert assertMsg (
        m != null
      ) "lib.rebellion.path.split-file-extension: File must have an extension.";
      m;

    ## Check if a file name has any file extension.
    #@ String -> Bool
    has-any-file-extension = file: (match file-name-regex (toString file)) != null;

    ## Get the file extension of a file name.
    #@ String -> String
    get-file-extension =
      file: if has-any-file-extension file then last (match file-name-regex (toString file)) else "";

    ## Check if a file name has a specific extension.
    #@ String -> String -> Bool
    has-file-extension =
      extension: file:
      if has-any-file-extension file then extension == get-file-extension file else false;

    ## Get the parent directory name for a given path.
    #@ Path -> String
    get-parent-directory = path: baseNameOf (dirOf path);

    ## Get the file name of a path without its extension.
    #@ Path -> String
    get-file-name-without-extension =
      path:
      let
        file-name = baseNameOf path;
      in
      if has-any-file-extension file-name then
        concatStringsSep "" (init (split-file-extension file-name))
      else
        file-name;
  };
}
