# rbn-bootstrap.rsc — replaces MikroTik's factory ap-default.rsc.
#
# Run via `/system/reset-configuration no-defaults=yes skip-backup=yes
# run-after-reset=rbn-bootstrap.rsc`. The just bootstrap-device recipe
# renders this file via envsubst, SCPs it (plus wildcard cert/key) to
# /, and triggers the reset.
#
# envsubst allowlist (refer to vars without the dollar-brace form here to
# avoid them being substituted in the rendered output):
#   ROLE         router | switch
#   IDENTITY     e.g. "da-relay02"
#   MGMT_IP      counter-derived (router=10.42.0.1, relay02=.2, relay03=.3, ...)
#   VLAN_ID      42 (mgmt VLAN)
#   ADMIN_PW     rotated admin password (from sops)
#   TF_PW        terraform user password (from sops)
#   TRUNK_PORTS  comma-separated downstream-trunk ether ports for routers
#                (from topology.network.<relay>.trunks). Empty when no
#                downstream switches. Ignored on switch role.
#
# RouterOS runtime $vars ($eth1Mac, $leaseBound, $leaseActIP, $role,
# $identity, $certName, etc.) are NOT in the envsubst allowlist, so
# they survive untouched through render.

:local role        "${ROLE}"
:local identity    "${IDENTITY}"
:local mgmtIp      "${MGMT_IP}"
:local vlanId      ${VLAN_ID}
:local rootPw      "${ROOT_PW}"
:local tofuPw      "${TOFU_PW}"
:local trunkPorts  "${TRUNK_PORTS}"

:log info ("rbn-bootstrap: starting (role=" . $role . ") for " . $identity)

# ─── Identity + users (common) ────────────────────────────────────────────
:log info "rbn-bootstrap: [step 1] identity + users"
/system identity set name=$identity
/user set admin password=$rootPw

# `terraform` user lives in a custom restricted group (REST/API only — no
# shell, no UI, no reboot). Policy mirrors modules/mikrotik/users.tofu so
# tofu's first plan post-bootstrap shows zero drift.
/user/group add name=terraform \
  policy=api,rest-api,read,write,sensitive,policy,!reboot,!ssh,!telnet,!ftp,!winbox,!web,!local,!password,!sniff,!test \
  comment="Restricted: REST/API only, no shell/UI/reboot. Address allowlist via tofu."
/user add name=terraform group=terraform password=$tofuPw \
  comment="Managed by tofu - bootstrap-created"

# ─── Bridge (common) ──────────────────────────────────────────────────────
# admin-mac pinned to factory ether1's MAC so downstream DHCP/ARP/etc.
# stay stable across bridge rebuilds.
:log info "rbn-bootstrap: [step 2] bridge + ports"
:local eth1Mac [/interface/ethernet/get [find default-name=ether1] mac-address]
/interface/bridge add name=bridge auto-mac=no admin-mac=$eth1Mac \
  protocol-mode=rstp comment="bootstrap"

# Bridge ports — router excludes ether1 (it's WAN); switch includes it (trunk)
:if ($role = "router") do={
  :foreach iface in=[/interface/ethernet/find where !(name="ether1")] do={
    /interface/bridge/port add bridge=bridge \
      interface=[/interface/ethernet/get $iface name] comment="bootstrap"
  }
} else={
  :foreach iface in=[/interface/ethernet/find] do={
    /interface/bridge/port add bridge=bridge \
      interface=[/interface/ethernet/get $iface name] comment="bootstrap"
  }
}

# ─── Interface lists (LAN common; WAN router-only) ───────────────────────
/interface/list add name=LAN comment="bootstrap"
/interface/list/member add list=LAN interface=bridge comment="bootstrap"
:if ($role = "router") do={
  /interface/list add name=WAN comment="bootstrap"
  /interface/list/member add list=WAN interface=ether1 comment="bootstrap"
}

# ─── mgmt VLAN sub-interface (common) ────────────────────────────────────
:log info "rbn-bootstrap: [step 3] mgmt VLAN sub-interface"
/interface/vlan add name=mgmt vlan-id=$vlanId interface=bridge \
  comment="bootstrap: Management"
/interface/list/member add list=LAN interface=mgmt comment="bootstrap"

# ─── Bridge VLAN entry ───────────────────────────────────────────────────
# Routers tag mgmt on `bridge` (for L3 termination) and any downstream
# trunk ports declared in topology.network.<relay>.trunks. Switches always
# tag mgmt on `bridge` + ether1 (the upstream trunk to the router).
:local taggedList "bridge"
:if ($role = "router") do={
  :if ([:len $trunkPorts] > 0) do={
    :set taggedList ($taggedList . "," . $trunkPorts)
  }
} else={
  :set taggedList ($taggedList . ",ether1")
}
/interface/bridge/vlan add bridge=bridge vlan-ids=$vlanId \
  tagged=$taggedList untagged=ether2 comment="bootstrap"
/interface/bridge/port set [find interface=ether2] pvid=$vlanId

# ─── mgmt IP ─────────────────────────────────────────────────────────────
# Routers: static counter-derived assignment (.1 — they ARE the L3
# router on mgmt and own the DHCP pool).
# Switches: DHCP client on mgmt. relay01's tofu-managed static lease
# (keyed on the switch's bridge-mac from sops) ensures the assigned IP
# matches topology convention (.<counter>). Prerequisite: relay01 must
# be bootstrapped AND `tofu apply`d first so the static lease exists.
:log info "rbn-bootstrap: [step 4] mgmt IP (router=static / switch=DHCP)"
:if ($role = "router") do={
  /ip/address add address=($mgmtIp . "/24") interface=mgmt network=10.42.0.0 \
    comment="bootstrap"
} else={
  /ip/dhcp-client add interface=mgmt disabled=no comment="bootstrap: mgmt"
}

# ─── L3 setup: router does DHCP/DNS/NAT; switch gets a default route ─────
:if ($role = "router") do={
  # WAN DHCP client (ISP)
  /ip/dhcp-client add interface=ether1 disabled=no comment="bootstrap: WAN"

  # mgmt DHCP server.
  # No lease-script — clients (laptops, IoT) aren't meant to be name-
  # addressable on the mgmt VLAN. Backbone devices are handled via:
  #   - self-entry below (router registers itself)
  #   - tofu's main module DNS sync (siblings — see plan #11)
  /ip/pool add name=pool-mgmt ranges=10.42.0.20-10.42.0.254 comment="bootstrap"
  /ip/dhcp-server add name=dhcp-mgmt interface=mgmt address-pool=pool-mgmt \
    disabled=no comment="bootstrap"
  /ip/dhcp-server/network add address=10.42.0.0/24 gateway=$mgmtIp \
    dns-server=$mgmtIp domain=holonet.jm0.io comment="bootstrap"

  # DNS: upstream resolvers + serve LAN.
  # No self-entry in /ip/dns/static — once tofu's main module applies,
  # `<dc>-<relay>.holonet.jm0.io` resolves via Cloudflare to the relay's
  # wg-holonet IP, which is reachable from any VLAN (the router routes
  # 10.42.<dc>.0/24 via its own wg-holonet interface). Avoids leaking
  # the mgmt-VLAN IP to guest/iot clients via internal DNS answers.
  # During the bootstrap window itself, the just bootstrap-device recipe
  # uses `curl --resolve` to map hostname → mgmt IP, so this entry isn't
  # needed for the bootstrap polling either.
  /ip/dns set servers=9.9.9.9,1.1.1.1 allow-remote-requests=yes

  # NAT — bare masquerade out WAN (tofu adds dst-nat etc. later)
  /ip/firewall/nat add chain=srcnat action=masquerade out-interface-list=WAN \
    comment="bootstrap"

  # Forward chain (routers only — switches don't route)
  /ip/firewall/filter add chain=forward action=fasttrack-connection \
    connection-state=established,related comment="bootstrap"
  /ip/firewall/filter add chain=forward action=accept \
    connection-state=established,related,untracked comment="bootstrap"
  /ip/firewall/filter add chain=forward action=drop \
    connection-state=invalid comment="bootstrap"
  /ip/firewall/filter add chain=forward action=drop \
    connection-state=new connection-nat-state=!dstnat \
    in-interface-list=WAN comment="bootstrap"
} else={
  # Switch: default route + DNS arrive via the mgmt-VLAN DHCP lease
  # from relay01 (gateway = dns-server = 10.42.0.1, set by relay01's
  # /ip/dhcp-server/network). Nothing to configure here beyond the DHCP
  # client added above.
}

# ─── Minimal input firewall (common) ─────────────────────────────────────
:log info "rbn-bootstrap: [step 5] input firewall"
# Comments match what tofu's `modules/mikrotik/firewall.tofu` writes for
# r01 / r08 / r09 / r11 — that way the per-relay tofu file imports these
# rules by internal id (*1..*4) and adopts them with zero diff. After
# adoption, tofu's main module owns these resources; subsequent re-
# bootstraps are picked up the same way (state refresh removes the old
# id mapping, import block grabs the new one).
/ip/firewall/filter add chain=input action=accept \
  connection-state=established,related,untracked \
  comment="defconf: accept established,related,untracked"
/ip/firewall/filter add chain=input action=drop \
  connection-state=invalid \
  comment="defconf: drop invalid"
/ip/firewall/filter add chain=input action=accept protocol=icmp \
  comment="defconf: accept ICMP"
/ip/firewall/filter add chain=input action=drop in-interface-list=!LAN \
  comment="defconf: drop all not coming from LAN"

# ─── Wildcard cert + key (common; SCPed alongside this script) ───────────
# RouterOS auto-pairs the key to its cert by public-key match.
#
# Brief delay before import — during `run-after-reset` boot, the cert
# subsystem comes up slowly and imports silently no-op, leaving www-ssl
# pointing at the auto-generated self-signed cert. The post-import
# verification + log makes that failure mode loud instead of invisible
# (tofu apply would later die with "connection reset by peer" because
# www-ssl can't actually serve TLS without a paired cert+key).
:log info "rbn-bootstrap: [step 6] cert import"
:delay 3s
/certificate/import name="holonet" file-name=wildcard.crt passphrase=""
/certificate/import name="holonet" file-name=wildcard.key passphrase=""
:if ([:len [/certificate/find where name~"holonet"]] = 0) do={
  :log error "rbn-bootstrap: cert import FAILED — no 'holonet' cert present; www-ssl will not serve a valid TLS cert"
} else={
  :log info "rbn-bootstrap: cert imported OK"
  /file/remove [find name~"wildcard"]
}

# ─── SSH host key (optional; PKCS#8 ed25519) ─────────────────────────────
# TEMPORARILY DISABLED — isolating whether this block is the cause of the
# bootstrap timeout on relay02. Re-enable once confirmed innocent.
#
# When `just upload` SCPs /relay-host.pem (from secrets/hosts/<dc>-<relay>
# .sops.yaml :: .host-key), import it so the device's SSH host identity
# stays stable across reset-configuration runs. Silently skipped if no
# file is present.
#
# Wrapped in :do/:on-error so a malformed key or unsupported format can't
# abort the rest of the script — critical because vlan-filtering=yes (the
# very last step) MUST run for the switch to pass tagged mgmt VLAN frames
# to the upstream router. Without it, no DHCP discover ever leaves.
#:do {
#  :if ([:len [/file find name="relay-host.pem"]] > 0) do={
#    /ip/ssh/import-host-key key-file-name=relay-host.pem
#    /file/remove [find name=relay-host.pem]
#  }
#} on-error={
#  :log warning "rbn-bootstrap: ssh host key import failed; continuing"
#}

# ─── REST/SSH services ───────────────────────────────────────────────────
:log info "rbn-bootstrap: [step 7] services"
/ip/service set ssh disabled=no
/ip/service set www-ssl disabled=no certificate="holonet"
/ip/service set [find name=www] disabled=yes
/ip/service set [find name=telnet] disabled=yes
/ip/service set [find name=api] disabled=yes
/ip/service set [find name=api-ssl] disabled=yes

# ─── vlan-filtering LAST (disruptive — flips ether2 to mgmt VLAN) ────────
:log info "rbn-bootstrap: [step 8] vlan-filtering ON"
/interface/bridge set [find name=bridge] vlan-filtering=yes

:log info ("rbn-bootstrap: complete (role=" . $role . ") for " . $identity)
