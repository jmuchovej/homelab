# Cilium

## UniFi BGP

```sh
router bgp 64513
  bgp router-id 192.168.1.1
  no bgp ebgp-requires-policy

  neighbor k8s peer-group
  neighbor k8s remote-as 64514

  neighbor 192.168.42.10 peer-group k8s
  neighbor 192.168.42.11 peer-group k8s
  neighbor 192.168.42.12 peer-group k8s

  address-family ipv4 unicast
    neighbor k8s next-hop-self
    neighbor k8s soft-reconfiguration inbound
  exit-address-family
exit
```

## MikroTik BGP

```sh
# Configure BGP instance
/routing bgp connection
add name=k8s as=64513 remote.address=10.42.0.1

# Configure the template for the k8s peer group
# https://medium.com/@valentin.hristev/kubernetes-loadbalance-service-using-cilium-bgp-control-plane-8a5ad416546a
/routing bgp template
add name=k8s as=64512 address-families=ip local.role=ibgp output.default-originate=always routing-table=main disabled=no output.next-hop=self

# Configure neighbors using the template
/routing bgp connection
add name=da-vcx-1 remote.address=10.42.1.11 template=k8s
add name=da-vcx-2 remote.address=10.42.1.12 template=k8s
add name=da-vcx-3 remote.address=10.42.1.13 template=k8s

# Disable EBGP policy requirement
/routing bgp instance set default check-gateway-reachability=no
```
