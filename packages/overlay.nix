{ inputs }:
final: _prev:
let
  inherit (final) lib;
  inherit (lib) makeScope recurseIntoAttrs;

  # name -> package.nix. Same-named directories would otherwise collapse
  # silently.
  discover =
    dir:
    let
      entries = lib.pipe inputs.import-tree [
        (i: i.filter (lib.hasSuffix "/package.nix"))
        (i: i.map (p: lib.nameValuePair (baseNameOf (dirOf p)) p))
        (i: i.leaves dir)
      ];
      duplicates = lib.pipe entries [
        (lib.groupBy (e: e.name))
        (lib.filterAttrs (_: es: builtins.length es > 1))
        (lib.mapAttrsToList (name: es: "${name}: ${lib.concatMapStringsSep ", " (e: toString e.value) es}"))
        (lib.concatStringsSep "; ")
      ];
    in
    if duplicates == "" then
      lib.listToAttrs entries
    else
      throw "rbn: duplicate package names under ${toString dir} (${duplicates})";

  call-all = self: dir: lib.mapAttrs (_: p: self.callPackage p { }) (discover dir);
in
{
  rbn = recurseIntoAttrs (
    makeScope final.newScope (
      self:
      call-all self ./by-name
      // {
        fonts = recurseIntoAttrs (makeScope self.newScope (fonts: call-all fonts ./fonts));
      }
    )
  );
}
