# https = //github.com/noborus/ov/blob/master/ov-less.yaml
{ config, lib, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.rebellion.programs.tools.ov;
in
{
  options.rebellion.programs.tools.ov = {
    enable = mkEnableOption "ov";
  };

  config = mkIf cfg.enable {
    #   programs.ov = {
    #     enable = true;

    #     replaceLess             = true;
    #     enableBatIntegration    = true;
    #     enableDeltaIntegration  = true;

    #     settings = {
    #       # mostly drawn from the `ov-less.yaml` while i figure how i feel about `ov`.
    #       Prompt = {
    #         Normal = {
    #           ShowFilename    = true;
    #           InvertColor     = true;
    #           ProcessOfCount  = true;
    #         };
    #       };
    #       General = {
    #         TabWidth        = 2;
    #         Header          = 0;
    #         AlternateRows   = false;
    #         ColumMode       = false;
    #         LineNumMode     = false;
    #         WrapMode        = true ;
    #         ColumnDelimiter = ",";
    #         MarkStyleWidth  = 1;
    #       };

    #       KeyBind = {
    #           exit = [ "Escape"  "q" ];
    #           cancel = [ "ctrl+c" ];
    #           write_exit = [ "Q" ];
    #           set_write_exit = [ "ctrl+q" ];
    #           suspend = [ "ctrl+z" ];
    #           sync = [ "r"  "ctrl+l" ];
    #           reload = [ "R"  "ctrl+r" ];
    #           watch = [ "T"  "ctrl+alt+w" ];
    #           watch_interval = [ "ctrl+w" ];
    #           follow_mode = [ "F" ];
    #           follow_all = [ "ctrl+a" ];
    #           follow_section = [ "F2" ];
    #           help = [ "h"  "ctrl+alt+c" ];
    #           logdoc = [ "ctrl+alt+e" ];
    #           down = [ "e"  "ctrl+e"  "j"  "J"  "ctrl+j"  "Enter"  "Down" ];
    #           up = [ "y"  "Y"  "ctrl+y"  "k"  "K"  "ctrl+K"  "Up" ];
    #           top = [ "Home"  "g"  "<" ];
    #           bottom = [ "End"  ">"  "G" ];
    #           left = [ "left" ];
    #           right = [ "right" ];
    #           half_left = [ "ctrl+left" ];
    #           half_right = [ "ctrl+right" ];
    #           page_up = [ "PageUp"  "b"  "alt+v" ];
    #           page_down = [ "PageDown"  "ctrl+v"  "alt+space"  "f"  "z" ];
    #           page_half_up = [ "u"  "ctrl+u" ];
    #           page_half_down = [ "d"  "ctrl+d" ];
    #           section_delimiter = [ "alt+d" ];
    #           section_start = [ "ctrl+F3"  "alt+s" ];
    #           section_header_num = [ "F7" ];
    #           hide_other = [ "alt+" ];
    #           next_section = [ "space" ];
    #           last_section = [ "9" ];
    #           previous_section = [ "^" ];
    #           mark = [ "m" ];
    #           remove_mark = [ "M" ];
    #           remove_all_mark = [ "ctrl+delete" ];
    #           next_mark = [ "alt+>" ];
    #           previous_mark = [ "alt+<" ];
    #           set_view_mode = [ "p"  "P" ];
    #           alter_rows_mode = [ "C" ];
    #           line_number_mode = [ "alt+n" ];
    #           search = [ "/" ];
    #           wrap_mode = [ "w"  "W" ];
    #           column_mode = [ "c" ];
    #           backsearch = [ "?" ];
    #           delimiter = [ "d" ];
    #           header = [ "H" ];
    #           skip_lines = [ "ctrl+s" ];
    #           tabwidth = [ "t" ];
    #           goto = [ " = " ];
    #           next_search = [ "n" ];
    #           next_backsearch = [ "N" ];
    #           next_doc = [ "]" ];
    #           previous_doc = [ "[" ];
    #           toggle_mouse = [ "ctrl+alt+r" ];
    #           multi_color = [ "." ];
    #           jump_target = [ "alt+j" ];
    #       };

    #       Mode = {
    #         markdown = {
    #           SectionDelimiter =  "^#";
    #           WrapMode =  true;
    #         };
    #         psql = {
    #           Header =  2;
    #           AlternateRows =  true;
    #           ColumnMode =  true;
    #           LineNumMode =  false;
    #           WrapMode =  true;
    #           ColumnDelimiter =  "|";
    #         };
    #         mysql = {
    #           Header =  3;
    #           AlternateRows =  true;
    #           ColumnMode =  true;
    #           LineNumMode =  false;
    #           WrapMode =  true;
    #           ColumnDelimiter =  "|";
    #         };
    #       };
    #     };
    #   };

    #   home.sessionVariables = {
    #     # Configure `ov` as the default pager
    #     DELTA_PAGER = "ov -F";
    #     PAGER = "ov -F -H3";
    #     MANPAGER = "ov --section-delimiter '^[^\s]' --section-header";
    #   };
    #   home.shellAliases = {
    #     less = "ov";
    #   };
  };
}
