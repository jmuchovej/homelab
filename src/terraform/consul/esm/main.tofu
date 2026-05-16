## ACL policy + token for consul-esm (the External Service Monitor that runs
## the health checks for the agentless external nodes registered in
## da.consul.tofu — relay01/02, hubitat). Rules are the upstream-documented
## ESM policy: it needs node/service write to update catalog health, agent
## read, a session for leader election, and write on its own KV prefix.
##
## The generated token's secret_id is exposed as a sensitive output. After
## `tofu apply`, push it into sops for the NixOS service to consume (the value
## arg must be valid JSON, hence the embedded quotes):
##
##   TOKEN="$(tofu output -raw consul-esm-token)"
##   sops set secrets/da.sops.yaml '["consul"]["esm-token"]' "\"$TOKEN\""
terraform {
  required_providers {
    consul = { source = "hashicorp/consul" }
  }
}

variable "datacenter" {
  type = string
}

resource "consul_acl_policy" "esm" {
  name        = "consul-esm"
  description = "External Service Monitor — health checks for agentless external nodes"
  datacenters = [var.datacenter]

  rules = <<-RULE
    agent_prefix "" {
      policy = "read"
    }
    node_prefix "" {
      policy = "write"
    }
    service_prefix "" {
      policy = "write"
    }
    session_prefix "" {
      policy = "write"
    }
    key_prefix "consul-esm/" {
      policy = "write"
    }
  RULE
}

resource "consul_acl_token" "esm" {
  description = "consul-esm external service monitor"
  policies    = [consul_acl_policy.esm.name]
  local       = false
}

data "consul_acl_token_secret_id" "esm" {
  accessor_id = consul_acl_token.esm.id
}

output "esm-token" {
  value     = data.consul_acl_token_secret_id.esm.secret_id
  sensitive = true
}
