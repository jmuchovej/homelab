{
  devices = {
    "da-vcx-1" = "2PVQ7GG-6PBNKT7-QBRC6OT-H3HFR6P-YUYHMQG-6APDE4E-FP4K2BB-TDCYXA3";
    "da-vcx-2" = "F3TGLV6-KJYOTHH-VDDOVYU-I2BFIWV-WXMGHAV-V7BXYTA-2PCMJW5-4EOCTAZ";
    "da-vcx-3" = "Y5LZ4PJ-ABBPXBK-4RTL2TV-S4TTW46-NCZM4YJ-3ZZLKSU-QXI57L7-XKD6NQD";
    "da-n1x" = "O2EZQBZ-DXPJUBN-ABOO2KV-2N35LZM-ORLBROK-SVDXHH7-2IS4HWD-D5NUOAH";
    "en-t65-1" = "VD7NWJR-TCGEIEG-LBPDJJJ-7ELQIAB-3RIAXDT-2OWR3PD-FTORLRI-MZ7FVAN";
  };

  folders = {
    "Syncthing:John" = {
      id = "kgdfv-4mme4";
      owner = "john";
    };
    "Syncthing:James" = {
      id = "n2l9r-1pa6d";
      owner = "james";
    };
    "Syncthing:Angela" = {
      id = "0r8tl-mp6gb";
      owner = "angela";
    };
    "Syncthing:Julia" = {
      id = "uxlb9-6emzg";
      owner = "julia";
    };
  };

  # Hosts that mirror every folder.
  servers = [
    "da-vcx-1"
    "da-vcx-2"
    "da-vcx-3"
    "en-t65-1"
  ];

  # Clients: hostname → owner whose folder to sync.
  clients = {
    "da-n1x" = "john";
  };
}
