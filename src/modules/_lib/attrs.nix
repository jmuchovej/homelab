## Attribute-set helpers. Currently just `merge-deep` — recursive merge of a
## list of attrsets, later wins at each level.
{ lib, ... }:
{
  _rbn-lib = {
    merge-deep = lib.foldl' lib.recursiveUpdate { };
  };
}
