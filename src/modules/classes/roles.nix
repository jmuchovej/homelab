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
  den.ctx.user.includes = [ role-class ];
  den.ctx.default.includes = [ role-class ];
}
