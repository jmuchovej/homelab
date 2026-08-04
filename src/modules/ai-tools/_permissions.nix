{
  commands = {
    "fd:*" = "allow";
    "find:*" = "deny";
    "rg:*" = "allow";
    "grep:*" = "deny";

    "gh search issues:*" = "allow";
    "gh search prs:*" = "allow";
    "gh issue view:*" = "allow";
    "gh pr view:*" = "allow";
    "gh api:*" = "allow";

    "jj op:*" = "allow";
    "jj log:*" = "allow";
    "jj bookmark:*" = "allow";
    "jj show:*" = "allow";
    "jj status:*" = "allow";
    "jj config:*" = "allow";
    "jj file:*" = "allow";
    "jj split:*" = "allow";
    "jj diff:*" = "allow";

    "nix flake:*" = "allow";

    "kubectl get:*" = "allow";
    "kubectl get secret:*" = "deny";
    "kubectl explain:*" = "allow";
    "kubectl describe:*" = "allow";
    "kubectl describe secret:*" = "deny";
    "kubectl logs:*" = "allow";
    "kubectl events:*" = "allow";
    "kubectl top:*" = "allow";
    "kubectl api-resources:*" = "allow";
    "kubectl api-versions:*" = "allow";

    "kubectl config view:*" = "deny";
    "kubectl config set:*" = "deny";
    "kubectl config unset:*" = "deny";
    "kubectl config use-context:*" = "deny";

    "kubectl apply:*" = "deny";
    "kubectl create:*" = "deny";
    "kubectl delete:*" = "deny";
    "kubectl edit:*" = "deny";
    "kubectl patch:*" = "deny";
    "kubectl replace:*" = "deny";
    "kubectl set:*" = "deny";
    "kubectl label:*" = "deny";
    "kubectl annotate:*" = "deny";
    "kubectl scale:*" = "deny";
    "kubectl autoscale:*" = "deny";
    "kubectl rollout:*" = "deny";
    "kubectl expose:*" = "deny";
    "kubectl run:*" = "deny";
    "kubectl exec:*" = "deny";
    "kubectl attach:*" = "deny";
    "kubectl cp:*" = "deny";
    "kubectl debug:*" = "deny";
    "kubectl port-forward:*" = "deny";
    "kubectl proxy:*" = "deny";
    "kubectl drain:*" = "deny";
    "kubectl cordon:*" = "deny";
    "kubectl uncordon:*" = "deny";
    "kubectl taint:*" = "deny";
    "kubectl certificate:*" = "deny";
    "kubectl auth reconcile:*" = "deny";
    "kubectl cluster-info dump:*" = "deny";
  };

  domains = {
    "raw.githubusercontent.com" = "allow";
    "github.com" = "allow";
    "openbao.org" = "allow";
    "mynixos.com" = "allow";
    "registry.terraform.io" = "allow";
    "devenv.sh" = "allow";
    "flake.parts" = "allow";
    "docs.goauthentik.io" = "allow";
    "integrations.goauthentik.io" = "allow";
    "tailscale.com" = "allow";
    "nixos.org" = "allow";
    "noogle.dev" = "allow";
    "nix.dev" = "allow";
    "api.github.com" = "deny";
    "kdl.dev" = "allow";
    "den.denful.dev" = "allow";
    "import-tree.denful.dev" = "allow";
    "search.nixos.org" = "allow";
  };
}
