group "default" {
    targets = [ "base" ]
}

target "base" {
    context = "./.devcontainer"
    dockerfile = "Dockerfile"
    platforms = [ "linux/amd64", "linux/arm64", ]
    args = {
      SOPS_VERSION = "3.9.1"
    }
    labels = {
        "org.opencontainers.image.title" = "Homelab Dev Container"
    }
    tags = [
        "ghcr.io/jmuchovej/homelab/devcontainer:base",
    ]
}

