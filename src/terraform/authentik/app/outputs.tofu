output "uuid" {
  value = authentik_application.app.uuid
}

output "app_id" {
  value = authentik_application.app.id
}

output "provider_id" {
  value = local.provider.id
}

output "provider" {
  value = local.provider
}
