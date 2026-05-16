# `/modules/nixos/` - NixOS System Modules

This directory contains **NixOS system modules** for declarative system
configuration in the `rebellion` homelab. These modules manage system-level
services, hardware configuration, kernel parameters, and other aspects of the
operating system that require root privileges.

## Overview

NixOS modules in `rebellion` provide declarative system configuration management
for:

- **System services and daemons**
- **Hardware configuration and drivers**
- **Kernel parameters and boot configuration**
- **Network configuration and security**
- **Container orchestration (Kubernetes/K3s)**
- **System users and permissions**
- **Storage and filesystem management**
- **Security hardening and compliance**

## Directory Structure

```
modules/nixos/
├── AGENTS.md                    # This file
├── boot/                        # Boot configuration modules
│   ├── grub/                   # GRUB bootloader config
│   ├── systemd-boot/           # systemd-boot config
│   └── kernel/                 # Kernel parameters and modules
├── containers/                  # Container orchestration
│   ├── kubernetes/             # K3s and Kubernetes config
│   ├── docker/                 # Docker daemon config
│   └── podman/                 # Podman container runtime
├── hardware/                    # Hardware-specific modules
│   ├── cpu/                    # CPU-specific optimizations
│   ├── gpu/                    # Graphics card configuration
│   ├── network/                # Network hardware config
│   └── storage/                # Storage device configuration
├── networking/                  # Network configuration
│   ├── firewall/               # Firewall rules and policies
│   ├── dns/                    # DNS configuration
│   ├── vpn/                    # VPN services (Tailscale, etc.)
│   └── routing/                # Advanced routing config
├── security/                    # Security hardening modules
│   ├── authentication/         # PAM, LDAP, etc.
│   ├── encryption/             # LUKS, TPM, etc.
│   ├── monitoring/             # Security monitoring tools
│   └── policies/               # Security policies and SELinux
├── services/                    # System services
│   ├── backup/                 # System backup services
│   ├── database/               # Database services
│   ├── monitoring/             # System monitoring (Prometheus, etc.)
│   ├── proxy/                  # Reverse proxies, load balancers
│   └── storage/                # Storage services (NFS, Samba, etc.)
├── system/                      # Core system configuration
│   ├── fonts/                  # System-wide font management
│   ├── locale/                 # Localization settings
│   ├── time/                   # Time synchronization
│   └── users/                  # System user management
└── virtualization/              # Virtualization technologies
    ├── libvirt/                # KVM/QEMU virtualization
    ├── containers/             # Container runtimes
    └── networking/             # Virtual networking
```

## Core Patterns

### 1. System Module Structure

All NixOS modules follow the `rebellion` namespace pattern:

```nix
# modules/nixos/services/monitoring/prometheus.nix
{ lib, config, pkgs, ... }:
let
  inherit (lib) mkIf types;
  inherit (lib.rebellion) mk-opt enabled disabled;

  cfg = config.rebellion.services.monitoring.prometheus;
in
{
  options.rebellion.services.monitoring.prometheus = {
    enable = mk-opt types.bool false "Enable Prometheus monitoring";

    port = mk-opt types.port 9090 "Prometheus web interface port";

    scrapeConfigs = mk-opt (types.listOf types.attrs) [ ]
      "Prometheus scrape configurations";

    retention = mk-opt types.str "30d"
      "Data retention period";

    storage = {
      path = mk-opt types.str "/var/lib/prometheus"
        "Data storage path";

      size = mk-opt types.str "10G"
        "Maximum storage size";
    };
  };

  config = mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      port = cfg.port;
      retentionTime = cfg.retention;
      dataDir = cfg.storage.path;
      scrapeConfigs = cfg.scrapeConfigs;
    };

    # Firewall configuration
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Storage management
    systemd.tmpfiles.rules = [
      "d ${cfg.storage.path} 0755 prometheus prometheus -"
    ];

    # System user
    users.users.prometheus = {
      isSystemUser = true;
      group = "prometheus";
      home = cfg.storage.path;
    };
    users.groups.prometheus = { };
  };
}
```

### 2. Hardware Configuration Pattern

Hardware modules provide declarative hardware management:

```nix
# modules/nixos/hardware/cpu/intel.nix
{ lib, config, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.rebellion) mk-opt;

  cfg = config.rebellion.hardware.cpu.intel;
in
{
  options.rebellion.hardware.cpu.intel = {
    enable = mk-opt lib.types.bool false "Enable Intel CPU optimizations";

    generation = mk-opt lib.types.str "auto"
      "Intel CPU generation (auto, haswell, skylake, etc.)";

    enableMicrocode = mk-opt lib.types.bool true
      "Enable Intel microcode updates";

    powerManagement = mk-opt lib.types.bool true
      "Enable Intel power management features";
  };

  config = mkIf cfg.enable {
    # CPU-specific optimizations
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

    # Microcode updates
    hardware.cpu.intel.updateMicrocode = cfg.enableMicrocode;

    # Power management
    powerManagement = mkIf cfg.powerManagement {
      enable = true;
      cpuFreqGovernor = "powersave";
    };

    # Kernel modules
    boot.kernelModules = [ "kvm-intel" ];

    # Generation-specific optimizations
    boot.kernelParams = lib.mkMerge [
      (lib.mkIf (cfg.generation == "haswell") [
        "intel_pstate=enable"
        "processor.max_cstate=1"
      ])
      (lib.mkIf (cfg.generation == "skylake") [
        "intel_pstate=enable"
        "intel_iommu=on"
      ])
    ];
  };
}
```

### 3. Service Integration Pattern

System services integrate with networking, security, and monitoring:

```nix
# modules/nixos/services/kubernetes/k3s.nix
{ lib, config, pkgs, ... }:
let
  inherit (lib) mkIf types;
  inherit (lib.rebellion) mk-opt enabled;

  cfg = config.rebellion.services.kubernetes;
in
{
  options.rebellion.services.kubernetes = {
    enable = mk-opt types.bool false "Enable K3s Kubernetes";

    role = mk-opt (types.enum [ "server" "agent" ]) "server"
      "K3s node role";

    leader = mk-opt types.bool false
      "Whether this is the cluster leader (first server)";

    serverAddress = mk-opt (types.nullOr types.str) null
      "Address of K3s server (for agents)";

    token = mk-opt (types.nullOr types.str) null
      "Cluster join token";

    clusterCIDR = mk-opt types.str "10.69.0.0/16"
      "Pod network CIDR";

    serviceCIDR = mk-opt types.str "10.70.0.0/16"
      "Service network CIDR";

    extraArgs = mk-opt (types.listOf types.str) [ ]
      "Additional K3s arguments";
  };

  config = mkIf cfg.enable {
    # K3s service configuration
    services.k3s = {
      enable = true;
      role = cfg.role;
      serverAddr = cfg.serverAddress;
      token = cfg.token;
      extraFlags = [
        "--cluster-cidr=${cfg.clusterCIDR}"
        "--service-cidr=${cfg.serviceCIDR}"
        "--disable=traefik"  # Use external ingress
        "--disable=servicelb"  # Use Cilium LB
        "--flannel-backend=none"  # Use Cilium CNI
      ] ++ cfg.extraArgs;
    };

    # Network configuration
    networking.firewall = {
      allowedTCPPorts = [
        6443  # K3s API server
        10250  # Kubelet
      ];
      allowedTCPPortRanges = [
        { from = 30000; to = 32767; }  # NodePort range
      ];
      allowedUDPPorts = [
        8472  # Flannel VXLAN (backup)
      ];
    };

    # System prerequisites
    boot.kernel.sysctl = {
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
      "net.ipv4.ip_forward" = 1;
    };

    # Required kernel modules
    boot.kernelModules = [ "br_netfilter" "overlay" ];

    # Container runtime dependencies
    virtualisation.containerd.enable = true;

    # Bootstrap services for Flux and apps
    systemd.services = lib.mkMerge [
      (lib.mkIf cfg.leader {
        k3s-bootstrap-flux = {
          description = "Bootstrap Flux GitOps";
          after = [ "k3s.service" ];
          wantedBy = [ "multi-user.target" ];
          path = with pkgs; [ kubectl flux ];
          script = ''
            # Wait for K3s to be ready
            until kubectl cluster-info &>/dev/null; do
              echo "Waiting for K3s API server..."
              sleep 5
            done

            # Bootstrap Flux if not already present
            if ! kubectl get namespace flux-system &>/dev/null; then
              flux bootstrap github \
                --owner=organization \
                --repository=homelab \
                --branch=main \
                --path=./kubernetes/flux
            fi
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };

        k3s-bootstrap-apps = {
          description = "Bootstrap Kubernetes applications";
          after = [ "k3s-bootstrap-flux.service" ];
          wants = [ "k3s-bootstrap-flux.service" ];
          wantedBy = [ "multi-user.target" ];
          path = with pkgs; [ kubectl helmfile ];
          script = ''
            # Wait for Flux to be ready
            until kubectl get pods -n flux-system | grep -q "Running"; do
              echo "Waiting for Flux to be ready..."
              sleep 10
            done

            # Apply bootstrap applications
            cd /etc/nixos/kubernetes/bootstrap
            helmfile apply
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
        };
      })
    ];

    # Backup script for cluster state
    rebellion.services.backup.restic = {
      enable = true;
      jobs.k3s = {
        paths = [ "/var/lib/rancher/k3s" ];
        schedule = "daily";
        repository = "s3:backup-bucket/k3s-${config.networking.hostName}";
      };
    };

    # Monitoring integration
    rebellion.services.monitoring.prometheus = {
      scrapeConfigs = [
        {
          job_name = "kubernetes-apiservers";
          kubernetes_sd_configs = [
            { role = "endpoints"; }
          ];
          scheme = "https";
          tls_config = {
            ca_file = "/var/lib/rancher/k3s/server/tls/server-ca.crt";
            cert_file = "/var/lib/rancher/k3s/server/tls/client-admin.crt";
            key_file = "/var/lib/rancher/k3s/server/tls/client-admin.key";
          };
        }
      ];
    };
  };
}
```

## Common Module Categories

### 1. System Services

**Purpose**: Configure system-level services and daemons **Location**:
`services/`

Key patterns:

- Use systemd service definitions
- Configure proper dependencies and ordering
- Integrate with firewall and networking
- Provide monitoring and logging
- Handle secrets securely

### 2. Hardware Configuration

**Purpose**: Configure hardware-specific settings and drivers **Location**:
`hardware/`

Key patterns:

- Detect hardware capabilities
- Load appropriate kernel modules
- Configure power management
- Set hardware-specific kernel parameters
- Enable vendor-specific features

### 3. Network Configuration

**Purpose**: Configure network interfaces, routing, and security **Location**:
`networking/`

Key patterns:

- Define network interfaces declaratively
- Configure firewall rules
- Set up routing and VLANs
- Integrate with external network infrastructure
- Provide DNS and DHCP services

### 4. Security Modules

**Purpose**: Implement security hardening and compliance **Location**:
`security/`

Key patterns:

- Configure authentication systems
- Implement access controls
- Enable audit logging
- Set up encryption
- Apply security policies

## Development Workflows

### Creating New NixOS Modules

1. **Identify the module category**:
   - System service → `services/{category}/`
   - Hardware config → `hardware/{type}/`
   - Network feature → `networking/{feature}/`
   - Security feature → `security/{feature}/`

2. **Create module file**:

   ```bash
   touch modules/nixos/services/monitoring/my-service.nix
   ```

3. **Follow the system module template**:

   ```nix
   { lib, config, pkgs, ... }:
   let
     inherit (lib) mkIf;
     inherit (lib.rebellion) mk-opt enabled;

     cfg = config.rebellion.services.monitoring.my-service;
   in
   {
     options.rebellion.services.monitoring.my-service = {
       enable = mk-opt lib.types.bool false "Enable my-service";
       # Add service-specific options
     };

     config = mkIf cfg.enable {
       # System configuration
       systemd.services.my-service = {
         description = "My Service";
         wantedBy = [ "multi-user.target" ];
         serviceConfig = {
           Type = "simple";
           ExecStart = "${pkgs.my-service}/bin/my-service";
         };
       };

       # Network configuration
       networking.firewall.allowedTCPPorts = [ 8080 ];

       # User/group creation
       users.users.my-service = {
         isSystemUser = true;
         group = "my-service";
       };
       users.groups.my-service = { };
     };
   }
   ```

4. **Test the module**:

   ```bash
   # Enable in system config
   rebellion.services.monitoring.my-service = enabled;

   # Build and test
   nixos-rebuild build --flake .#hostname
   nixos-rebuild test --flake .#hostname  # Non-persistent test
   nixos-rebuild switch --flake .#hostname  # Apply permanently
   ```

### Integration with Suite System

NixOS modules integrate with the suite system:

```nix
# In suites/cluster.nix
rebellion.suites.cluster = {
  nixos = {
    services = {
      kubernetes = {
        enable = true;
        role = "server";
      };
      monitoring.prometheus = enabled;
      backup.restic = enabled;
    };

    networking = {
      firewall.kubernetes = enabled;
      dns.k8s-gateway = enabled;
    };

    hardware = {
      # Auto-detected based on system
      cpu.intel = lib.mkIf (detectCpuVendor == "intel") enabled;
      cpu.amd = lib.mkIf (detectCpuVendor == "amd") enabled;
    };
  };
};
```

### Multi-System Configuration

Handle different system types and roles:

```nix
# In system configuration
config = lib.mkMerge [
  # Base configuration for all systems
  {
    rebellion.services.monitoring.node-exporter = enabled;
    rebellion.security.hardening.basic = enabled;
  }

  # K3s server configuration
  (lib.mkIf (cfg.role == "k3s-server") {
    rebellion.services.kubernetes = {
      enable = true;
      role = "server";
      leader = cfg.isLeader;
    };
  })

  # K3s agent configuration
  (lib.mkIf (cfg.role == "k3s-agent") {
    rebellion.services.kubernetes = {
      enable = true;
      role = "agent";
      serverAddress = cfg.serverAddress;
    };
  })

  # Development system extras
  (lib.mkIf config.rebellion.suites.development.enable {
    rebellion.services.development.docker = enabled;
    virtualisation.libvirtd.enable = true;
  })
];
```

## Testing & Debugging

### Testing NixOS Modules

```bash
# Build system configuration
nix build .#nixosConfigurations.hostname.config.system.build.toplevel

# Test in VM
nixos-rebuild build-vm --flake .#hostname
./result/bin/run-vm

# Dry run to see what would change
nixos-rebuild dry-build --flake .#hostname

# Test without persistence
nixos-rebuild test --flake .#hostname
```

### Debugging System Services

```bash
# Check service status
systemctl status my-service

# View service logs
journalctl -u my-service -f

# Check service dependencies
systemctl list-dependencies my-service

# Restart service
systemctl restart my-service

# Check service configuration
systemd-analyze verify my-service.service
```

### Network Debugging

```bash
# Check firewall rules
iptables -L -n -v

# Test network connectivity
ss -tulpn | grep :port
nc -zv hostname port

# Check routing
ip route show
ip addr show

# DNS resolution
systemd-resolve --status
dig hostname
```

### Hardware Debugging

```bash
# Check hardware detection
lshw -short
lscpu
lsblk

# Check kernel modules
lsmod | grep module-name
modinfo module-name

# Check kernel messages
dmesg | grep -i error
journalctl -k -f
```

## Security Considerations

### 1. Service Isolation

```nix
# Use proper service isolation
systemd.services.my-service = {
  serviceConfig = {
    DynamicUser = true;
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ReadWritePaths = [ "/var/lib/my-service" ];
  };
};
```

### 2. Secret Management

```nix
# Use sops-nix for secrets
config.sops.secrets.my-service-password = {
  sopsFile = ../../secrets/systems/${config.networking.hostName}.sops.yaml;
  owner = "my-service";
  mode = "0400";
};

# Reference secrets in service
systemd.services.my-service = {
  serviceConfig = {
    LoadCredential = "password:${config.sops.secrets.my-service-password.path}";
  };
};
```

### 3. Network Security

```nix
# Principle of least privilege for firewall
networking.firewall = {
  allowedTCPPorts = [ ]; # Avoid this

  # Prefer specific interface rules
  interfaces.eth0.allowedTCPPorts = [ 80 443 ];

  # Or source-based rules
  extraCommands = ''
    iptables -A INPUT -p tcp --dport 9090 -s 10.42.1.0/24 -j ACCEPT
  '';
};
```

## Performance Optimization

### 1. Service Optimization

```nix
# Optimize service startup
systemd.services.my-service = {
  serviceConfig = {
    # Reduce startup time
    Type = "notify";
    TimeoutStartSec = "30s";

    # Resource limits
    CPUQuota = "200%";
    MemoryLimit = "1G";

    # I/O optimization
    IOSchedulingClass = 2;
    IOSchedulingPriority = 4;
  };
};
```

### 2. Kernel Optimization

```nix
# System-wide kernel tuning
boot.kernel.sysctl = {
  # Network performance
  "net.core.rmem_max" = 16777216;
  "net.core.wmem_max" = 16777216;
  "net.ipv4.tcp_rmem" = "4096 12582912 16777216";
  "net.ipv4.tcp_wmem" = "4096 12582912 16777216";

  # File system performance
  "vm.dirty_ratio" = 15;
  "vm.dirty_background_ratio" = 5;
  "vm.swappiness" = 10;
};
```

## Integration with Kubernetes

### 1. K3s Configuration

The K3s module provides comprehensive Kubernetes cluster setup:

- **Server/Agent roles** with automatic cluster joining
- **CNI integration** with Cilium for advanced networking
- **Load balancer integration** with BGP advertisement
- **Storage provisioning** with local-path-provisioner
- **Monitoring integration** with Prometheus service discovery

### 2. Flux GitOps Bootstrap

Automated GitOps setup:

- **Flux installation** and GitHub repository bootstrap
- **Application deployment** via Helmfile
- **Secret management** integration with SOPS
- **Cluster state backup** with Restic

### 3. Network Integration

Kubernetes networking integrates with system networking:

- **BGP peering** with MikroTik router
- **LoadBalancer IP advertisement** via Cilium
- **Service mesh preparation** with Istio support
- **Network policy enforcement** via Cilium

## Best Practices

### 1. Module Organization

- **Single responsibility**: Each module should handle one service or feature
- **Composable design**: Modules should work independently and together
- **Clear dependencies**: Explicitly declare module dependencies
- **Proper namespacing**: Use `rebellion.{category}.{service}` consistently

### 2. Service Configuration

- **Use systemd best practices**: Proper service types, dependencies, and
  isolation
- **Handle failures gracefully**: Configure restart policies and health checks
- **Provide monitoring hooks**: Integrate with Prometheus and logging
- **Document configuration**: Clear option descriptions and examples

### 3. Security by Default

- **Minimal permissions**: Services should run with least necessary privileges
- **Network isolation**: Use firewall rules to restrict access
- **Secret management**: Never store secrets in plain text
- **Regular updates**: Keep services and dependencies current

## Common Gotchas

1. **Service Ordering**: Ensure proper `after` and `wants` dependencies
2. **Firewall Rules**: Remember to open necessary ports
3. **User/Group Creation**: System services need proper user accounts
4. **File Permissions**: Ensure service users can access required files
5. **Module Loading**: Some hardware requires specific kernel modules
6. **Network Interfaces**: Interface names may vary between systems
7. **Storage Paths**: Ensure storage directories exist and have correct
   permissions

## Reference Examples

See existing modules for implementation patterns:

- `services/kubernetes/k3s.nix` - Complex service with networking
- `hardware/cpu/intel.nix` - Hardware-specific optimization
- `networking/firewall/` - Network security configuration
- `security/hardening/` - System security policies

For integration examples, examine how suites compose multiple modules in the
`suites/` directory.
