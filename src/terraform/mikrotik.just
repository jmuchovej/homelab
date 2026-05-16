MIKROTIK_USER := "terraform"

[private]
default:
    @just --list

# Query a MikroTik REST API endpoint authenticated as the `terraform` user.
#
# Usage:
#   just via-mikrotik-api relay01.en interface/list/member
#   just via-mikrotik-api relay02.da ip/address
#
# `target` is `<relay>.<dc>` — e.g. `relay01.en` selects relay01 in the en DC.
# Password comes from secrets/{dc}.sops.yaml at `mikrotik.{relay}.terraform-password`.
# Router IP defaults to 10.42.0.<N> where N is the relay number (relay01→.1, relay02→.2).
# Output is raw JSON — pipe through `yq -p json` for pretty-printing.
via-mikrotik-api target route:
    #!/usr/bin/env bash
    set -euo pipefail
    target="{{ target }}"
    relay="${target%.*}"
    dc="${target#*.}"
    n="${relay#relay0}"
    host="10.42.0.${n}"
    path="{{ justfile_directory() }}/secrets/hosts/${dc}-${relay}.sops.yaml"
    pw="$(sops -d ${path} | yq -e ".tofu-password")"
    curl -ksu "{{ MIKROTIK_USER }}:${pw}" "http://${host}/rest/{{ route }}"

list-interfaces target:
    @just via-mikrotik-api {{ target }} interface/list/member | \
      yq -p json '.[] | (.[".id"] + " \tlist=" + .list + "\tinterface=" + .interface)'

import-bridge-in-lan target:
    @just list-interfaces {{ target }} | \
      rg 'list=LAN' | \
      rg 'interface=bridge'

import-wan-uplink target:
    @just list-interfaces {{ target }} | \
      rg 'list=WAN' | \
        rg 'interface=ether1'

import-accept-holonet target:
    @just via-mikrotik-api {{ target }} ip/firewall/filter \
      | yq '.[] | select(.comment | test("wg-holonet")) | .[".id"]'
