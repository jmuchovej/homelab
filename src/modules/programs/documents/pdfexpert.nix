_: {
  rbn.programs._.documents._.pdfexpert.darwin =
    { host, lib, ... }:
    lib.mkIf host.homebrew.enable {
      homebrew.casks = [ "pdf-expert" ];
    };
}
