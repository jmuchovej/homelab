data "authentik_rbac_permission" "all" {
  for_each = toset([
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

    # events
    "view_event",
    "add_event",
    "view_notification",
    "view_notificationrule",
    "view_notificationtransport",
    "view_notificationwebhookmapping",

    # flows
    "view_flow",
    "view_flow_cache",
    "view_flowstagebinding",
    "view_flowtoken",
    "view_stage",

    # outposts
    "view_dockerserviceconnection",
    "view_kubernetesserviceconnection",
    "view_outpost",
    "view_outpostserviceconnection",

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

    # providers
    "view_ldapprovider",
    "view_accesstoken",
    "view_authorizationcode",
    "view_devicetoken",
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

    # rbac
    "view_initialpermissions",
    "view_role",
    "access_admin_interface",
    "view_system_info",
    "view_system_settings",
    "view_media_files",

    # stages - authenticator
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

    # stages - other
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

    # tasks
    "view_task",
    "view_schedule",

    # tenants
    "view_domain",
    "view_tenant",
  ])

  codename = each.value
}
