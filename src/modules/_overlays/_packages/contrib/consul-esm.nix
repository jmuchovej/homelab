{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "consul-esm";
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "hashicorp";
    repo = "consul-esm";
    rev = "v${version}";
    hash = "sha256-LwUb16rJqUkgj1RxLhcUBEYdg1llzeFYIYlPIue+E0k=";
  };

  vendorHash = "sha256-l3qlUhNkeyfzQScWtz3CzZ0pcDHWKUlxkjIis619crg=";

  ldflags = [
    "-s"
    "-w"
    "-X github.com/hashicorp/consul-esm/version.GitDescribe=v${version}"
  ];

  # No network in the sandbox — the suite spins up a live Consul agent.
  doCheck = false;

  meta = {
    description = "Health checks for external services registered in the Consul catalog";
    homepage = "https://github.com/hashicorp/consul-esm";
    license = lib.licenses.mpl20;
    mainProgram = "consul-esm";
  };
}
