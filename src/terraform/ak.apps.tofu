data "consul_services" "all" {
  query_options {
    datacenter = local.datacenter
  }
}

locals {
  service-names = split(" ",
    lookup(data.consul_services.all.tags, "authentik.enable=true", "")
  )

  service-tags = {
    for name in local.service-names :
    name => [
      for tag, services in data.consul_services.all.tags :
      replace(tag, "authentik.", "")
      if strcontains(services, name) && startswith(tag, "authentik.")
    ]
  }

  services = {
    for service, tags in local.service-tags : service => {
      for tag in tags :
      regex("([^=]+)=.*$", tag)[0] => regex("[^=]+=(.*)$", tag)[0]
    }
  }

  apps = {
    for service, tags in local.services : service => {
      name       = lookup(tags, "name", service)
      group      = lookup(tags, "group", "Ungrouped")
      type       = lookup(tags, "type", "proxy")
      icon       = lookup(tags, "icon", service)
      access     = split(",", lookup(tags, "access", "users"))
      skip_paths = lookup(tags, "skip-paths", null)
      basic_auth = {
        enabled  = lookup(tags, "basic-auth.enabled", "false") == "true"
        username = lookup(tags, "basic-auth.username", "username")
        password = lookup(tags, "basic-auth.password", "password")
      }
      url = {
        int = lookup(tags, "url.int", "")
        ext = lookup(tags, "url.ext", "")
      }
    }
  }
}

module "authentik-app" {
  source   = "./modules/authentik-app"
  for_each = local.apps

  name            = each.value.name
  group           = each.value.group
  type            = each.value.type
  icon            = each.value.icon
  internal        = each.value.url.int
  external        = each.value.url.ext
  launch_url      = each.value.url.ext
  skip_path_regex = each.value.skip_paths
  access_group    = [for access in each.value.access : local.groups[access].id]
  basic_auth      = each.value.basic_auth
  signing_key     = authentik_certificate_key_pair.wildcard.id

  flows = {
    ldap = {
      bind   = authentik_flow.ldap.uuid
      unbind = authentik_flow.invalidation.uuid
    }
    proxy = {
      authorization = authentik_flow.authz-explicit.uuid
      invalidation  = authentik_flow.invalidation.uuid
    }
    oauth = {
      authentication = authentik_flow.authn.uuid
      authorization  = authentik_flow.authz-explicit.uuid
      invalidation   = authentik_flow.invalidation.uuid
    }
  }

  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.oidc.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}
