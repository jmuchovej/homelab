## YAML helpers: reading YAML into Nix, and rendering YAML templates.
##
##   from-yaml   — parse a YAML file into an attrset. Needs `pkgs` (there is no
##                 `builtins.fromYAML`), so this is import-from-derivation.
##   render-yaml — substitute `@marker@` placeholders in a YAML template,
##                 throwing on either unused vars or leftover markers.
##
## Both take `pkgs`/args explicitly rather than closing over them: `defaults.nix`
## constructs these helpers with only `{ lib, inputs }`, so `pkgs` is never
## ambient here.
{ lib, ... }:
let
  inherit (lib)
    attrNames
    concatStringsSep
    filter
    hasInfix
    replaceStrings
    splitString
    ;
  inherit (builtins) match readFile;
in
{
  _rbn-lib = {
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

    # Guards in both directions: a var you passed but the template never uses is
    # as likely a mistake as a marker the template has but you never filled.
    render-yaml =
      file: vars:
      let
        src = readFile file;
        names = attrNames vars;
        unused = filter (n: !(hasInfix "@${n}@" src)) names;
        out = replaceStrings (map (n: "@${n}@") names) (map (n: vars.${n}) names) src;
        leftover = filter (line: match ".*@[a-z0-9-]+@.*" line != null) (splitString "\n" out);
      in
      if unused != [ ] then
        throw "render-yaml ${baseNameOf file}: unused vars: ${concatStringsSep ", " unused}"
      else if leftover != [ ] then
        throw "render-yaml ${baseNameOf file}: unsubstituted markers: ${concatStringsSep " " leftover}"
      else
        out;
  };
}
