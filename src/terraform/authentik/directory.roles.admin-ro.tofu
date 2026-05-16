locals {
  admin-ro-permissions = {
    core = toset([
      # blueprints
      "view_blueprintinstance",
      # brands
      "view_brand",
      # core
      "view_application",
      "view_applicationentitlement",
      "view_authenticatedsession",
      "view_group",
      "view_groupsourceconnection",
      "view_propertymapping",
      "view_provider",
      "view_source",
      "view_token",
      "view_token_key",
      "view_user",
      "preview_user",
      "view_user_applications",
      "view_usersourceconnection",
      # crypto
      "view_certificatekeypair",
    ])

    flows-policies = toset([
      # flows
      "view_flow",
      "view_flow_cache",
      "view_flowstagebinding",
      "view_flowtoken",
      "view_stage",
      # policies
      "view_policy",
      "view_policy_cache",
      "view_policybinding",
      "view_policybindingmodel",
      "view_dummypolicy",
      "view_eventmatcherpolicy",
      "view_passwordexpirypolicy",
      "view_expressionpolicy",
      "view_geoippolicy",
      "view_passwordpolicy",
      "view_reputation",
      "view_reputationpolicy",
      "view_uniquepasswordpolicy",
      "view_userpasswordhistory",
    ])

    providers = toset([
      "view_ldapprovider",
      "view_accesstoken",
      "view_authorizationcode",
      # codename collides across apps (endpoints + oauth2) so it's absent from
      # the discovered map; written in full form to pass through lookup().
      "authentik_providers_oauth2.view_devicetoken",
      "view_oauth2provider",
      "view_refreshtoken",
      "view_scopemapping",
      "view_proxyprovider",
      "view_proxysession",
      "view_connectiontoken",
      "view_endpoint",
      "view_racpropertymapping",
      "view_racprovider",
      "view_radiusprovider",
      "view_radiusproviderpropertymapping",
      "view_samlpropertymapping",
      "view_samlprovider",
      "view_samlsession",
      "view_scimmapping",
      "view_scimprovider",
      "view_scimprovidergroup",
      "view_scimprovideruser",
    ])

    events-infra = toset([
      # events
      "view_event",
      "view_notification",
      "view_notificationrule",
      "view_notificationtransport",
      "view_notificationwebhookmapping",
      # outposts
      "view_dockerserviceconnection",
      "view_kubernetesserviceconnection",
      "view_outpost",
      "view_outpostserviceconnection",
      # rbac
      "view_initialpermissions",
      "view_role",
      "access_admin_interface",
      "view_system_info",
      "view_system_settings",
      "view_media_files",
      # tasks
      "view_task",
      "view_schedule",
      # tenants
      "view_domain",
      "view_tenant",
    ])

    stages-auth = toset([
      "view_authenticatorduostage",
      "view_duodevice",
      "view_authenticatoremailstage",
      "view_emaildevice",
      "view_authenticatorendpointgdtcstage",
      "view_endpointdevice",
      "view_endpointdeviceconnection",
      "view_authenticatorsmsstage",
      "view_smsdevice",
      "view_authenticatorstaticstage",
      "view_staticdevice",
      "view_statictoken",
      "view_authenticatortotpstage",
      "view_totpdevice",
      "view_authenticatorvalidatestage",
      "view_authenticatorwebauthnstage",
      "view_webauthndevice",
      "view_webauthndevicetype",
    ])

    stages-other = toset([
      "view_captchastage",
      "view_consentstage",
      "view_userconsent",
      "view_denystage",
      "view_dummystage",
      "view_emailstage",
      "view_identificationstage",
      "view_invitation",
      "view_invitationstage",
      "view_mutualtlsstage",
      "view_passwordstage",
      "view_prompt",
      "view_promptstage",
      "view_redirectstage",
      "view_sourcestage",
      "view_userdeletestage",
      "view_userloginstage",
      "view_userlogoutstage",
      "view_userwritestage",
    ])
  }
}

resource "authentik_rbac_role" "admin-ro-core" {
  name = "Admin RO: Core"
}

resource "authentik_rbac_permission_role" "admin-ro-core" {
  for_each   = local.admin-ro-permissions.core
  role       = authentik_rbac_role.admin-ro-core.id
  permission = lookup(var.permissions, each.value, each.value)
}

resource "authentik_rbac_role" "admin-ro-flows-policies" {
  name = "Admin RO: Flows & Policies"
}

resource "authentik_rbac_permission_role" "admin-ro-flows-policies" {
  for_each   = local.admin-ro-permissions.flows-policies
  role       = authentik_rbac_role.admin-ro-flows-policies.id
  permission = lookup(var.permissions, each.value, each.value)
}

resource "authentik_rbac_role" "admin-ro-providers" {
  name = "Admin RO: Providers"
}

resource "authentik_rbac_permission_role" "admin-ro-providers" {
  for_each   = local.admin-ro-permissions.providers
  role       = authentik_rbac_role.admin-ro-providers.id
  permission = lookup(var.permissions, each.value, each.value)
}

resource "authentik_rbac_role" "admin-ro-events-infra" {
  name = "Admin RO: Events & Infrastructure"
}

resource "authentik_rbac_permission_role" "admin-ro-events-infra" {
  for_each   = local.admin-ro-permissions.events-infra
  role       = authentik_rbac_role.admin-ro-events-infra.id
  permission = lookup(var.permissions, each.value, each.value)
}

resource "authentik_rbac_role" "admin-ro-stages-auth" {
  name = "Admin RO: Authenticator Stages"
}

resource "authentik_rbac_permission_role" "admin-ro-stages-auth" {
  for_each   = local.admin-ro-permissions.stages-auth
  role       = authentik_rbac_role.admin-ro-stages-auth.id
  permission = lookup(var.permissions, each.value, each.value)
}

resource "authentik_rbac_role" "admin-ro-stages-other" {
  name = "Admin RO: Other Stages"
}

resource "authentik_rbac_permission_role" "admin-ro-stages-other" {
  for_each   = local.admin-ro-permissions.stages-other
  role       = authentik_rbac_role.admin-ro-stages-other.id
  permission = lookup(var.permissions, each.value, each.value)
}

resource "authentik_group" "admin-ro" {
  name         = "Admin Read-only"
  is_superuser = false
  roles = [
    authentik_rbac_role.admin-ro-core.id,
    authentik_rbac_role.admin-ro-flows-policies.id,
    authentik_rbac_role.admin-ro-providers.id,
    authentik_rbac_role.admin-ro-events-infra.id,
    authentik_rbac_role.admin-ro-stages-auth.id,
    authentik_rbac_role.admin-ro-stages-other.id,
  ]
}
