{
  lib,
  ...
}:
let
  inherit (lib)
    mapAttrsToList
    mapAttrs
    mkDefault
    mkForce
    flatten
    foldl'
    recursiveUpdate
    mergeAttrs
    isDerivation
    ;
in
{
  attrs = {
    ## Apply mkDefault to all values in an attrset.
    #@ Attrs -> Attrs
    mk-default = mapAttrs (_key: mkDefault);

    ## Apply mkForce to all values in an attrset.
    #@ Attrs -> Attrs
    mk-force = mapAttrs (_key: mkForce);

    ## Map and flatten an attribute set into a list.
    #@ (String -> a -> [b]) -> Attrs -> [b]
    map-concat-attrs-to-list = f: attrs: flatten (mapAttrsToList f attrs);

    ## Recursively merge a list of attribute sets.
    #@ [Attrs] -> Attrs
    merge-deep = foldl' recursiveUpdate { };

    ## Merge the root of a list of attribute sets.
    #@ [Attrs] -> Attrs
    merge-shallow = foldl' mergeAttrs { };

    ## Merge shallow for packages, but allow one deeper layer of attribute sets.
    #@ [Attrs] -> Attrs
    merge-shallow-packages =
      items:
      foldl' (
        result: item:
        result
        // (mapAttrs (
          name: value:
          if isDerivation value then
            value
          else if builtins.isAttrs value then
            (result.${name} or { }) // value
          else
            value
        ) item)
      ) { } items;
  };
}
