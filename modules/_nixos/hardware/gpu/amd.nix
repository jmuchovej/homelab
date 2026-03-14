{ lib, ... }@args:
lib.rebellion.mk-module args {
  name = "hardware.gpu.amd";
  description = "AMD GPUs";
  config = _: { };
}
