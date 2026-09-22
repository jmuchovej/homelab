{ den, lib, ... }:
let
  role-class =
    { host, user }:
    { class, aspect-chain }:
    den._.forward {
      each = lib.intersectLists (host.roles or [ ]) (user.roles or [ ]);
      fromClass = lib.id;
      intoClass = _: host.class;
      intoPath = _: [ ];
      fromAspect = _: lib.head aspect-chain;
    };
in
{
  den.schema = {
    user.includes = [ role-class ];
    default.includes = [ role-class ];
  };
}
