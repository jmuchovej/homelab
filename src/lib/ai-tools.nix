{
  lib,
  rebellion-lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    drop
    elemAt
    filter
    findFirst
    hasPrefix
    listToAttrs
    nameValuePair
    removePrefix
    removeSuffix
    splitString
    trim
    ;
  inherit (rebellion-lib.fs) import-subdirs;

  ## Strip surrounding double-quotes from a string.
  strip-quotes = s: removePrefix "\"" (removeSuffix "\"" s);

  ## Parse a single "key: value" line into a name-value pair.
  ## Strips surrounding quotes from the value.
  parse-line =
    line:
    let
      m = builtins.match "([^:]+): (.*)" line;
    in
    nameValuePair (trim (elemAt m 0)) (strip-quotes (trim (elemAt m 1)));
in
{
  ai-tools = {

    ## Parse YAML-like frontmatter from a markdown string into an attrset.
    ## Expects "---\n<key: value lines>\n---\n<body>".
    ## Returns { description = "..."; allowed-tools = "..."; ... } or {} on failure.
    #@ String -> Attrs
    parse-frontmatter =
      contents:
      let
        parts = splitString "---\n" contents;
        has-frontmatter = builtins.length parts >= 3;
        raw = if has-frontmatter then elemAt parts 1 else "";
        lines = filter (line: line != "" && !(hasPrefix "#" line)) (splitString "\n" raw);
        parsed = filter (line: builtins.match "([^:]+): (.*)" line != null) lines;
      in
      if has-frontmatter then listToAttrs (map parse-line parsed) else { };

    ## Extract the body (everything after the closing ---) from a frontmatter markdown string.
    ## Rejoins any --- that appeared in the body itself.
    #@ String -> String
    extract-body =
      contents:
      let
        parts = splitString "---\n" contents;
      in
      if builtins.length parts >= 3 then
        trim (concatStringsSep "---\n" (drop 2 parts))
      else
        trim contents;

    ## Extract the description field from frontmatter, or null if absent.
    #@ String -> String | Null
    extract-description =
      contents:
      let
        parts = splitString "---\n" contents;
        has-frontmatter = builtins.length parts >= 3;
        raw = if has-frontmatter then elemAt parts 1 else "";
        lines = splitString "\n" raw;
        desc-line = findFirst (line: hasPrefix "description:" line) null lines;
      in
      if desc-line != null then strip-quotes (trim (removePrefix "description:" desc-line)) else null;

    ## Parse a command/agent markdown file into a structured attrset.
    ## Returns { command-name, guide, <frontmatter fields...> }.
    #@ String -> String -> Attrs
    parse-command-md =
      filename: contents:
      let
        parts = splitString "---\n" contents;
        frontmatter = elemAt parts 1;
        guide = trim (concatStringsSep "---\n" (drop 2 parts));
        lines = filter (
          line: line != "" && !(hasPrefix "#" line) && builtins.match "([^:]+): (.*)" line != null
        ) (splitString "\n" frontmatter);
        meta = listToAttrs (map parse-line lines);
      in
      meta
      // {
        command-name = removeSuffix ".md" filename;
        inherit guide;
      };

    ## Load commands and agents from a directory using import-subdirs.
    ## Returns { commands = { name = "raw md"; ... }; agents = { ... }; }.
    #@ Path -> Attrs
    load-tools = base-path: import-subdirs base-path { };
  };
}
