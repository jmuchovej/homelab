## rbn overlay — the repo-local packages/ tree as the `pkgs.rbn` fixed-point
## scope (apps at the top level, fonts nested under `pkgs.rbn.fonts`). Layout
## and resolution rules: AGENTS.md in this directory.
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

  # name -> package.nix for every package under `dir`, at any depth. The
  # attribute name is the package's own directory, so by-name shards vanish;
  # import-tree's default filter drops `_`-prefixed paths (parked builders).
  # Two directories with the same name would otherwise collapse silently.
  # Paths descend from `inputs.self` and carry store context, which an
  # attribute name may not, hence the discard on the name only.
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
