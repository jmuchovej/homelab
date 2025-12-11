{ inputs }:
_final: _prev:
let
  rebellion-lib = import ./default.nix { inherit inputs; };
in
{
  # Expose rebellion module functions directly
  rebellion = rebellion-lib.flake.lib.module // {

    # Expose all rebellion lib namespaces
    inherit (rebellion-lib.flake.lib)
      file
      system
      ;

    inherit (rebellion-lib.flake.lib.file)
      get-file
      get-nix-files
      import-files
      import-dir
      import-dir-plain
      import-subdirs
      import-modules-recursive
      merge-attrs
      ;
  };

  inherit (rebellion-lib.flake.lib.file)
    get-file
    get-nix-files
    import-files
    import-dir
    import-dir-plain
    import-subdirs
    import-modules-recursive
    merge-attrs
    ;

  inherit (rebellion-lib.flake.lib.module)
    mkopt
    mkopt'
    mkopt-bool
    mkopt-bool'
    mkopt-enable
    mkopt-package
    mkopt-package'
    enable-for-system
    mk-module
    get-shared
    mkopt-nested
    mkopt-nested-enable
    mkopt-vscode
    enable
    enabled
    disabled
    default-attrs
    force-attrs
    nested-default-attrs
    nested-force-attrs
    ;

  # Add home-manager lib functions
  inherit (inputs.home-manager.lib) hm;
}
