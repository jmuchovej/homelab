FROM mcr.microsoft.com/devcontainers/python:3.11-bookworm
ARG TARGETARCH
ARG SOPS_VERSION

SHELL ["/bin/bash", "-c"]

RUN pipx install nanolayer
 
RUN nanolayer install apt-get fish,zsh
RUN nanolayer install apt-get ca-certificates,curl,gnupg

RUN <<-EOF
export baseURL="https://pkgs.k8s.io/core:/stable:/v1.31/deb"
export keyFile="/etc/apt/keyrings/kubernetes.gpg"
export srcFile="/etc/apt/sources.list.d/kubernetes.list"
curl -fsSL "${baseURL}/Release.key" | gpg --dearmor -o "${keyFile}"
chmod 644 "${keyFile}"
echo "deb [signed-by=${keyFile}] ${baseURL}/ /" | tee "${srcFile}"
chmod 644 "${srcFile}"
nanolayer install apt-get kubectl
EOF

RUN nanolayer install apt-get \
    moreutils,gettext,git,iputils-ping,iputils-arping,iputils-tracepath,dnsutils,openssh-client

RUN curl -fsSL "https://i.jpillora.com/direnv/direnv!!?as=direnv"                | bash
RUN curl -fsSL "https://i.jpillora.com/starship/starship!!?as=starship"          | bash
RUN curl -fsSL "https://i.jpillora.com/eza-community/eza!!?as=eza"               | bash
RUN curl -fsSL "https://i.jpillora.com/junegunn/fzf!!?as=fzf"                    | bash
RUN curl -fsSL "https://i.jpillora.com/FiloSottile/age!!?as=age"                 | bash
RUN curl -fsSL "https://i.jpillora.com/cli/cli!!?as=gh"                          | bash
RUN curl -fsSL "https://i.jpillora.com/go-task/task!!?as=task"                   | bash
RUN curl -fsSL "https://i.jpillora.com/jqlang/jq!!?as=jq"                        | bash
RUN curl -fsSL "https://i.jpillora.com/mikefarah/yq!!?as=yq"                     | bash
RUN curl -fsSL "https://i.jpillora.com/cloudflare/cloudflared!!?as=cloudflared"  | bash
RUN curl -fsSL "https://i.jpillora.com/fluxcd/flux2!!?as=flux"                   | bash
RUN curl -fsSL "https://i.jpillora.com/cilium/cilium-cli!!?as=cilium"            | bash
RUN curl -fsSL "https://i.jpillora.com/derailed/k9s!!?as=k9s"                    | bash
RUN curl -fsSL "https://i.jpillora.com/helmfile/helmfile!!?as=helmfile"          | bash
RUN curl -fsSL "https://i.jpillora.com/kubecolor/kubecolor!!?as=kubecolor"       | bash
RUN curl -fsSL "https://i.jpillora.com/kubernetes-sigs/krew!!?as=krew"           | bash
RUN curl -fsSL "https://i.jpillora.com/kubernetes-sigs/kustomize!!?as=kustomize" | bash
RUN curl -fsSL "https://i.jpillora.com/yannh/kubeconform!!?as=kubeconform"       | bash
#! Currently unsupported! https://github.com/jpillora/installer/issues/43
# RUN curl -fsSL "https://i.jpillora.com/getsops/sops!!?as=sops"                   | bash
RUN curl -fsSL "https://i.jpillora.com/stern/stern!!?as=stern"                   | bash
RUN curl -fsSL "https://i.jpillora.com/siderolabs/talos!!?as=talosctl"           | bash
RUN curl -fsSL "https://i.jpillora.com/budimanjojo/talhelper!!?as=talhelper"     | bash
RUN curl -fsSL "https://i.jpillora.com/opentofu/opentofu!!?as=tofu"              | bash
RUN curl -fsSL "https://i.jpillora.com/helm/helm!!?as=helm"                      | bash
RUN curl -fsSL "https://i.jpillora.com/prefix-dev/pixi!!?as=pixi"                | bash

RUN curl -fsSL "https://github.com/helm/helm/raw/main/scripts/get-helm-3" | USE_SUDO="false" bash

RUN <<-EOF
export baseURL="https://github.com/getsops/sops/releases/download"
curl -L "${baseURL}/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${TARGETARCH}" -o /usr/local/bin/sops
chmod +x /usr/local/bin/sops
EOF

RUN <<-EOF
mkdir -p /home/vscode/.config/zsh/completions
for tool in cilium flux helm helmfile k8s kubectl kustomize talhelper talosctl tofu; do
  $tool completion zsh > /home/vscode/.config/zsh/completions/${tool}.zsh
done

gh completion --shell zsh > /home/vscode/.config/zsh/completions/gh.zsh
stern --completion zsh > /home/vscode/.config/zsh/completions/stern.zsh
yq shell-completion zsh > /home/vscode/.config/zsh/completions/yq.zsh
tofu -install-autocomplete
tee /home/vscode/.zshrc.local > /dev/null <<EOT
autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/local/bin/tofu tofu

eval "$(pixi shell-hook -s zsh)"
alias kubectl="kubecolor"
EOT
EOF

RUN <<-EOF
chown -R vscode:vscode /home/vscode/.config
EOF
