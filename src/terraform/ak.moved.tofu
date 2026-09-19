# Only apps discovered at MORE than one DC take a `-<site>` key and slug, so
# only those move. Everything single-site — the *arrs, immich, open-webui,
# homebox, split-pro, linkding, hubitat, the frozen entries and tailscale —
# keeps its bare name and is deliberately absent here.
#
# Without a `moved`, tofu reads the old address as gone and the new one as
# new: it destroys and recreates the application, discarding its provider and
# every consent bound to it.
#
# Selecting an existing app into a second cluster later puts it in this
# position too — it will surface in the plan as a replace, and its
# secrets/authentik.sops.yaml keys have to move with it.

moved {
  from = module.authentik.module.authentik-app["actual"]
  to   = module.authentik.module.authentik-app["actual-da"]
}
moved {
  from = module.authentik.module.authentik-app["n8n"]
  to   = module.authentik.module.authentik-app["n8n-da"]
}

# Outposts were one-per-type on a `count`; they are now one per site AND type.
moved {
  from = module.authentik.authentik_outpost.proxy[0]
  to   = module.authentik.authentik_outpost.site["da-proxy"]
}
moved {
  from = module.authentik.authentik_outpost.ldap[0]
  to   = module.authentik.authentik_outpost.site["da-ldap"]
}
moved {
  from = module.authentik.authentik_outpost.radius[0]
  to   = module.authentik.authentik_outpost.site["da-radius"]
}
