## Repo-root packages/ as the `pkgs.rbn` scope — layout and resolution rules
## are in AGENTS.md beside this file.
{ inputs }:
final: _prev:
let
  inherit (builtins) unsafeDiscardStringContext;
  inherit (final) lib;
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    filterAttrs
    groupBy
    hasSuffix
    listToAttrs
    makeScope
    mapAttrs
    mapAttrsToList
    nameValuePair
    recurseIntoAttrs
    ;

  packages-root = "${inputs.self}/packages";

  # name -> package.nix. Paths descend from `inputs.self` (a store path) and
  # so carry string context, which an attribute name may not: discard it on
  # the name only. Same-named directories would otherwise collapse silently.
  discover =
    dir:
    let
      entries = lib.pipe inputs.import-tree [
        (i: i.filter (hasSuffix "/package.nix"))
        (i: i.map (p: nameValuePair (unsafeDiscardStringContext (baseNameOf (dirOf p))) p))
        (i: i.leaves dir)
      ];
      duplicates = filterAttrs (_: es: builtins.length es > 1) (groupBy (e: e.name) entries);
      describe = name: es: "${name}: ${concatMapStringsSep ", " (e: toString e.value) es}";
    in
    if duplicates == { } then
      listToAttrs entries
    else
      throw "rbn: duplicate package names under ${dir} (${concatStringsSep "; " (mapAttrsToList describe duplicates)})";

  call-all = self: dir: mapAttrs (_: p: self.callPackage p { }) (discover dir);
in
{
  rbn = recurseIntoAttrs (
    makeScope final.newScope (
      self:
      call-all self "${packages-root}/by-name"
      // {
        fonts = recurseIntoAttrs (makeScope self.newScope (fonts: call-all fonts "${packages-root}/fonts"));
      }
    )
  );
}
