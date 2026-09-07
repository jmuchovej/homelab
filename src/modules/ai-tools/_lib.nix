## AI-tools helpers shared by every harness aspect: markdown loaders and
## frontmatter parsing for the `commands/`, `agents/`, and `skills/` trees, and
## the checked nushell builder for `hooks/*.nu`. Imported explicitly by
## sibling modules.
{ lib, import-tree }:
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
    hasSuffix
    trim
    getExe
    ;

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

  ## import-tree over markdown files. Values stay *paths*: stripping `.md`
  ## from a path coerces it to a store-path string minus its suffix, which
  ## Nix rejects, so the stem is only ever taken from the basename for keys.
  walk-md = import-tree (
    i: i.addAPI { to-keys = self: self.map (p: nameValuePair (removeSuffix ".md" (baseNameOf p)) p); }
  ) (i: i.initFilter (p: hasSuffix ".md" (toString p)));
in
{
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

  ## Load commands or agents from a directory, flattening any nesting
  ## (`commands/git/commit-msg.md` -> `commit-msg`), keyed by filename stem.
  ##
  ## Values are the `.md` paths themselves, not their contents:
  ## `programs.claude-code.{commands,agents}` is `attrsOf (either lines path)`,
  ## so a path works and avoids a `readFile` per file at eval time.
  ##
  ## `initFilter` must be overridden: import-tree's default filter only admits
  ## `.nix` files, and these trees hold markdown.
  #@ Path -> Attrs
  load-tools = base-path: listToAttrs (walk-md (i: i.to-keys) (i: i.leaves base-path));

  ## Load skills from a directory: each `<name>/SKILL.md` yields `<name>` ->
  ## its directory path, so the whole skill directory is what gets linked.
  #@ Path -> Attrs
  load-skills =
    base-path:
    listToAttrs (
      walk-md (i: i.filter (p: hasSuffix "/SKILL.md" (toString p))) (i: i.map dirOf) (i: i.to-keys) (
        i: i.leaves base-path
      )
    );

  ## Build `<hooks-dir>/<name>.nu` into a runnable, checked binary.
  ##
  ## `writers.writeNuBin` has no shellcheck equivalent built in, so `check`
  ## runs `nu-check` at build time; `--debug` makes a parse failure throw,
  ## failing the derivation with the diagnostic. Scripts run on the
  ## nixpkgs-pinned nushell, independent of the interactive shell's nu.
  ## `bins` end up on the script's wrapped PATH; nu built-ins cover the rest
  ## (mkdir/rm/date), so scripts list only their external commands.
  #@ { pkgs, hooks-dir } -> String -> { bins?, plugins? } -> Derivation
  mk-nu-script =
    { pkgs, hooks-dir }:
    name:
    {
      bins ? [ ],
      plugins ? [ ],
    }:
    let
      # Assembled from a list so the no-plugin case has no trailing space —
      # Linux passes the shebang tail as ONE argument, spaces included.
      nu = concatStringsSep " " (
        [
          (getExe pkgs.nushell)
          "--no-config-file"
        ]
        ++ lib.optionals (plugins != [ ]) [
          "--plugins"
          "'[${lib.concatMapStringsSep " " getExe plugins}]'"
        ]
      );
      nu-plugged = pkgs.writeShellScript "nu-plugged" ''exec ${nu} "$@"'';
      nu-check = pkgs.writeShellScript "nu-check" ''
        ${nu} --commands "if not (nu-check --debug '$1') { exit 1 }"
      '';
    in
    pkgs.writers.makeScriptWriter {
      interpreter = if plugins == [ ] then nu else toString nu-plugged;
      check = nu-check;
      makeWrapperArgs = lib.optionals (bins != [ ]) [
        "--prefix"
        "PATH"
        ":"
        (lib.makeBinPath bins)
      ];
    } "/bin/${name}" (builtins.readFile (hooks-dir + "/${name}.nu"));
}
