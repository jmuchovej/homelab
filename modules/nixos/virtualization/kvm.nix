{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "virtualization.kvm";
  description = "KVM";
}
