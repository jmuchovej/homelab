{
  lib,
  ...
}:
let
  inherit (lib) id foldr flip;
in
{
  fp = rec {
    ## Compose two functions: compose f g x = f (g x)
    #@ (b -> c) -> (a -> b) -> a -> c
    compose =
      f: g: x:
      f (g x);

    ## Compose a list of functions.
    #@ [(x -> y)] -> a -> b
    compose-all = foldr compose id;

    ## Call a function with an argument.
    #@ (a -> b) -> a -> b
    call = f: f;

    ## Apply an argument to a function (flipped call).
    #@ a -> (a -> b) -> b
    apply = flip call;
  };
}
