## Single source of truth for language servers consumed by both Zed and Claude
## Code. Imported explicitly by sibling modules (import-tree skips `_`-prefixed
## paths).
##
## Both harnesses spawn servers from an ambient `$PATH` that does NOT include
## the devenv/direnv environment, so every executable — the server itself and
## anything it shells out to — must be an absolute store path. Route packages
## through `mk-lsp` rather than naming a bare binary.
{ lib }:
let
  inherit (lib) getExe getBin optionalAttrs;
in
{
  # Claude's `.lsp.json` schema (verified against the 2.1.260 binary):
  # `command` (required, must not contain spaces — use `args`),
  # `extensionToLanguage` (required, non-empty; the ONLY source of both the
  # extension set and the LSP language IDs), plus optional `args`, `transport`
  # (stdio|socket, default stdio), `env`, `initializationOptions`, `settings`
  # and `workspaceFolder`. There is no built-in language list — any server
  # speaking LSP over stdio works.
  #
  # An entry defined by two modules does NOT conflict: attrs merge, equal
  # scalars collapse, but `args` lists CONCATENATE (`tombi lsp lsp`). A server
  # shared by several languages must live in its own aspect that each one
  # `includes`, never repeated per language.
  mk-lsp =
    {
      pkg,
      exe ? null,
      args ? [ ],
      init ? { },
      settings ? { },
      extensions ? { },
    }:
    let
      command = if exe == null then getExe pkg else "${getBin pkg}/bin/${exe}";
    in
    {
      inherit pkg;
      zed = {
        binary = {
          path = command;
          arguments = args;
        };
      }
      // optionalAttrs (init != { }) { initialization_options = init; }
      // optionalAttrs (settings != { }) { inherit settings; };

      claude = {
        inherit command args;
        extensionToLanguage = extensions;
      }
      // optionalAttrs (init != { }) { initializationOptions = init; }
      // optionalAttrs (settings != { }) { inherit settings; };
    };
}
