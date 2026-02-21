# `/homes/` - User Environment Configurations

This directory contains **home-manager configurations** for user environments in
the `rebellion` homelab. Each configuration defines a complete user environment
including applications, dotfiles, shell configuration, and user services across
different platforms and hosts.

## Overview

The `homes/` directory provides centralized user environment management for:

- **Cross-platform user configs** - Consistent environments across NixOS, macOS,
  and standalone systems
- **Host-specific customizations** - Tailored configurations for different
  machines
- **User-specific profiles** - Individual user preferences and workflows
- **Dotfile management** - Declarative configuration of shells, editors, and
  tools
- **Application deployment** - User-level application installation and
  configuration
- **Development environments** - Language toolchains and development tools
- **Service management** - User-level systemd services and background tasks

## Directory Structure

```
homes/
├── AGENTS.md                    # This file
├── aarch64-darwin/             # Apple Silicon macOS configurations
│   └── {user}@{hostname}/
│       ├── default.nix         # User home configuration
│       ├── packages.nix        # User-specific packages
│       └── dotfiles/           # User dotfiles (optional)
├── x86_64-linux/               # Intel/AMD64 Linux configurations
│   └── {user}@{hostname}/
│       ├── default.nix         # User home configuration
│       ├── packages.nix        # User-specific packages
│       ├── services.nix        # User services
│       └── dotfiles/           # User dotfiles (optional)
└── shared/                     # Shared configurations (optional)
    ├── profiles/               # Common user profiles
    ├── modules/                # Custom home-manager modules
    └── templates/              # Configuration templates
```

## User Configuration Architecture

### 1. User-Host Pairing Pattern

Each user configuration is paired with a specific host, allowing for
host-specific customizations while maintaining user identity across machines:

```
{user}@{hostname} structure:
- admin@da-vcx-1        # Admin user on Kubernetes leader
- admin@workstation-main # Admin user on macOS workstation  
- developer@da-vcx-2    # Developer user on cluster node
- john@macbook-pro      # Personal user on macOS laptop
```

### 2. Basic Home Configuration

All user configurations follow the `rebellion` home module pattern:

```nix
# homes/x86_64-linux/admin@da-vcx-1/default.nix
{ inputs, lib, pkgs, ... }:
{
  # Import shared configurations
  imports = [
    ./packages.nix
    ./services.nix
    ../../shared/profiles/developer.nix
  ];

  # Basic home-manager configuration
  home = {
    username = "admin";
    homeDirectory = "/home/admin";
    stateVersion = "24.05";
  };

  # Rebellion home modules
  rebellion.home = {
    # Shell configuration
    shell.zsh = {
      enable = true;
      aliases = {
        ll = "ls -alF";
        la = "ls -A";
        l = "ls -CF";
        
        # Kubernetes shortcuts
        k = "kubectl";
        kx = "kubectl config use-context";
        ks = "kubectl config set-context --current --namespace";
        
        # System shortcuts
        rebuild = "sudo nixos-rebuild switch --flake .";
        update = "nix flake update";
      };
      
      functions = {
        kexec = ''
          if [ $# -eq 0 ]; then
            echo "Usage: kexec <pod-selector> [namespace] [command]"
            return 1
          fi
          
          local selector=$1
          local namespace=${2:-default}
          local cmd=${3:-bash}
          
          local pod=$(kubectl get pods -n $namespace -l $selector --no-headers | head -1 | awk '{print $1}')
          if [ -n "$pod" ]; then
            kubectl exec -it $pod -n $namespace -- $cmd
          else
            echo "No pod found with selector: $selector"
          fi
        '';
      };
    };

    # Applications
    applications = {
      editors = {
        neovim = {
          enable = true;
          plugins = [
            "telescope-nvim"
            "nvim-lspconfig"
            "nvim-treesitter"
            "which-key-nvim"
          ];
          extraConfig = ''
            -- Leader key
            vim.g.mapleader = " "
            
            -- Basic settings
            vim.opt.number = true
            vim.opt.relativenumber = true
            vim.opt.tabstop = 2
            vim.opt.shiftwidth = 2
            vim.opt.expandtab = true
          '';
        };
        
        vscode = {
          enable = true;
          extensions = [
            "vscodevim.vim"
            "ms-vscode.vscode-json"
            "bbenoist.nix"
            "ms-kubernetes-tools.vscode-kubernetes-tools"
            "redhat.vscode-yaml"
          ];
          settings = {
            "editor.fontSize" = 14;
            "editor.fontFamily" = "FiraCode Nerd Font";
            "editor.fontLigatures" = true;
            "workbench.colorTheme" = "Dark+ (default dark)";
          };
        };
      };

      terminals.alacritty = {
        enable = true;
        settings = {
          font = {
            family = "FiraCode Nerd Font";
            size = 12;
          };
          colors = {
            primary = {
              background = "#1e1e1e";
              foreground = "#d4d4d4";
            };
          };
        };
      };
    };

    # Development tools
    development = {
      languages = {
        nix = {
          enable = true;
          lsp = true;
          formatter = "nixfmt";
        };
        
        go = {
          enable = true;
          version = "1.21";
          lsp = true;
        };
        
        python = {
          enable = true;
          version = "3.11";
          packages = [ "requests" "pyyaml" "black" "flake8" ];
        };
        
        rust = {
          enable = true;
          components = [ "rustc" "cargo" "rust-fmt" "rust-analyzer" ];
        };
      };

      tools = {
        git = {
          enable = true;
          userName = "Admin User";
          userEmail = "admin@rebellion.local";
          signing = {
            signByDefault = true;
            key = "0x1234567890ABCDEF";
          };
          extraConfig = {
            init.defaultBranch = "main";
            pull.rebase = true;
            push.autoSetupRemote = true;
          };
        };
        
        docker = {
          enable = true;
          enableBash = true;
        };
      };
    };

    # Services
    services = {
      gpg-agent = {
        enable = true;
        pinentryFlavor = "gtk2";
        defaultCacheTtl = 28800;  # 8 hours
      };
      
      syncthing = {
        enable = true;
        extraOptions = [ "--no-browser" ];
      };
    };
  };

  # Direct home-manager configuration
  programs = {
    # SSH configuration
    ssh = {
      enable = true;
      hosts = {
        "da-vcx-*" = {
          hostname = "10.42.1.%h";
          user = "admin";
          identityFile = "~/.ssh/rebellion_ed25519";
        };
        
        "*.rebellion.local" = {
          user = "admin";
          identityFile = "~/.ssh/rebellion_ed25519";
        };
      };
    };

    # GPG configuration
    gpg = {
      enable = true;
      settings = {
        trust-model = "tofu+pgp";
        default-key = "0x1234567890ABCDEF";
      };
    };
  };

  # XDG configuration
  xdg = {
    enable = true;
    configFile = {
      "k9s/config.yml".text = ''
        k9s:
          ui:
            enableMouse: true
            headless: false
            logoless: false
            crumbsless: false
          clusters:
            rebellion:
              namespace: 
                active: default
                favorites: 
                  - all
                  - kube-system
                  - flux-system
                  - monitoring
      '';
    };
  };
}
```

### 3. Platform-Specific Configuration

**macOS Configuration Example**:

```nix
# homes/aarch64-darwin/admin@workstation-main/default.nix
{ inputs, lib, pkgs, ... }:
{
  home = {
    username = "admin";
    homeDirectory = "/Users/admin";
    stateVersion = "24.05";
  };

  rebellion.home = {
    # macOS-specific shell configuration
    shell.zsh = {
      enable = true;
      aliases = {
        # macOS-specific aliases
        brewup = "brew update && brew upgrade";
        flushdns = "sudo dscacheutil -flushcache";
        showfiles
```
