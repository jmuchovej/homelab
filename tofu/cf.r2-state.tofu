import {
  to = cloudflare_r2_bucket.rbn
  id = "${data.cloudflare_zone.domain.account.id}/rbn/default"
}

resource "cloudflare_r2_bucket" "rbn" {
  account_id = data.cloudflare_zone.domain.account.id
  name       = "rbn"

  # This bucket holds the state tofu is reading right now.
  lifecycle {
    prevent_destroy = true
  }
}

# Both rule lists below are the bucket's COMPLETE configuration — the provider
# PUTs the whole thing, so any rule not declared here is deleted on apply.
# `rbn` is shared, so enumerate the live rules before editing either resource:
#   GET /accounts/<acct>/r2/buckets/rbn/{lifecycle,lock}

resource "cloudflare_r2_bucket_lifecycle" "rbn" {
  account_id  = data.cloudflare_zone.domain.account.id
  bucket_name = cloudflare_r2_bucket.rbn.name

  rules = [
    # Cloudflare's own default, carried verbatim. Dropping it would let
    # incomplete multipart uploads accumulate as billed storage forever.
    {
      id         = "Default Multipart Abort Rule"
      enabled    = true
      conditions = { prefix = "" }
      abort_multipart_uploads_transition = {
        condition = { type = "Age", max_age = 604800 } # 7d
      }
    },
    # R2 has no object versioning, so snapshots are the only state history.
    # max_age MUST exceed the lock retention below, or the lock suppresses the
    # delete and the prefix grows without bound.
    {
      id         = "expire-tofu-state-snapshots"
      enabled    = true
      conditions = { prefix = "tofu/snapshots/" }
      delete_objects_transition = {
        condition = { type = "Age", max_age = 31536000 } # 365d
      }
    },
  ]
}

resource "cloudflare_r2_bucket_lock" "rbn" {
  account_id  = data.cloudflare_zone.domain.account.id
  bucket_name = cloudflare_r2_bucket.rbn.name

  rules = [
    # Makes snapshots write-once: R2 locks forbid deletion AND overwriting, so
    # neither a stray script nor a leaked credential can erase state history.
    # The prefix must never cover tofu/terraform.tfstate or its .tflock — tofu
    # overwrites the live key on every write, and an empty prefix here scopes to
    # the whole bucket and bricks every apply.
    {
      id        = "retain-tofu-state-snapshots"
      enabled   = true
      prefix    = "tofu/snapshots/"
      condition = { type = "Age", max_age_seconds = 7776000 } # 90d
    },
  ]
}
