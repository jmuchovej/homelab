{
  den,
  lib,
  ...
}:
let
  # Gate an aspect on `host.desktop`, as a *named* policy rather than an
  # anonymous `{ host, ... }: lib.optionalAttrs (host.desktop or false) …`
  # include. Two reasons to prefer the policy form:
  #
  #   1. Identity. A named policy can be targeted by `excludes` (authoritative:
  #      a parent's exclude beats a child's include) and reads as itself in
  #      debug output. Anonymous include functions resolve to `<anon>`.
  #   2. Context-dependence. A function-valued aspect records the args it was
  #      resolved with (`fx/aspect.nix:107`), and `fx/handlers/emit-classes.nix`
  #      marks such an aspect context-dependent, which skips the `stripCtxSuffix`
  #      collapse — the same mechanism that duplicated `programs.zoxide.options`.
  #      Here the conditional lives in the policy; what gets injected is a plain,
  #      non-parametric aspect whose content keys stably.
  #
  # `name` is load-bearing, NOT decoration. den tags a policy-injected aspect
  # with the source policy's name (`fx/policy/apply.nix:36`) whenever the aspect
  # carries no `name` of its own — which `rbn.*` aspects don't — and `name` is
  # what the identity key is built from (`fx/identity.nix:9`). The `[idx]` suffix
  # den appends only separates several includes emitted by a *single* firing, so
  # two gates sharing a policy name would collapse onto one identity and one
  # aspect's content would be dropped without a warning.
  #
  # `host.desktop or false` rather than a bare `host.desktop`: a standalone home
  # resolves against a synthetic, classless host — or a null one when the home is
  # unbound — and `(null).desktop or false` is `false`, so GUI content stays out
  # of home-manager-only targets by construction.
  when-desktop =
    name: aspect:
    den.lib.policy.mkPolicy "when-desktop/${name}" (
      { host, ... }:
      lib.optional (host.desktop or false) (den.lib.policy.include aspect)
    );
in
{
  # Picked up by naming `rbn-policies` in a module's argument set.
  _module.args.rbn-policies = {
    inherit when-desktop;
  };

  den.schema.host.options.desktop = lib.mkOption {
    description = ''
      Whether this host drives a display, and so should receive GUI content.

      Gates aspect inclusion via `rbn-policies.when-desktop`, and is readable
      directly as `host.desktop` from aspect includes and class modules.
    '';
    type = lib.types.bool;
    default = false;
    example = true;
  };
}
