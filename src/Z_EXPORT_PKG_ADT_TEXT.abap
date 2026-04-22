*---------------------------------------------------------------------*
* Report  : Z_EXPORT_PKG_ADT_TEXT
* Purpose : Export package repository objects into a ZIP file
* Notes   : SAP_BASIS 7.51 compatible, conservative refactoring
*---------------------------------------------------------------------*
REPORT z_export_pkg_adt_text.

CONSTANTS gc_nl TYPE string VALUE cl_abap_char_utilities=>newline.

PARAMETERS: p_pack TYPE devclass OBLIGATORY,
            p_path TYPE string DEFAULT 'C:\temp\adt_export.zip'.

TYPES: tt_source TYPE STANDARD TABLE OF char255 WITH DEFAULT KEY.

TYPES: BEGIN OF ty_tadir,
         object   TYPE tadir-object,
         obj_name TYPE tadir-obj_name,
       END OF ty_tadir.
TYPES tt_tadir TYPE STANDARD TABLE OF ty_tadir WITH DEFAULT KEY.

TYPES tt_progname TYPE STANDARD TABLE OF progname WITH DEFAULT KEY.

TYPES: BEGIN OF ty_log,
         status   TYPE c LENGTH 1,
         object   TYPE trobjtype,
         obj_name TYPE sobj_name,
         message  TYPE string,
       END OF ty_log.
TYPES tt_log TYPE STANDARD TABLE OF ty_log WITH DEFAULT KEY.

TYPES: BEGIN OF ty_enlfdir,
         funcname TYPE rs38l_fnam,
         include  TYPE progname,
       END OF ty_enlfdir.
TYPES tt_enlfdir TYPE STANDARD TABLE OF ty_enlfdir WITH DEFAULT KEY.

CLASS lcl_text DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS append_line
      IMPORTING iv_line TYPE string
      CHANGING  cv_text TYPE string.
    CLASS-METHODS source_to_string
      IMPORTING it_source TYPE tt_source
      RETURNING VALUE(rv_text) TYPE string.
ENDCLASS.

CLASS lcl_text IMPLEMENTATION.
  METHOD append_line.
    IF cv_text IS INITIAL.
      cv_text = iv_line.
    ELSE.
      CONCATENATE cv_text iv_line INTO cv_text SEPARATED BY gc_nl.
    ENDIF.
  ENDMETHOD.

  METHOD source_to_string.
    DATA lv_line TYPE char255.

    CLEAR rv_text.

    LOOP AT it_source INTO lv_line.
      append_line(
        EXPORTING
          iv_line = lv_line
        CHANGING
          cv_text = rv_text ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_zip_writer DEFINITION.
  PUBLIC SECTION.
    METHODS add_file
      IMPORTING iv_name    TYPE string
                iv_content TYPE string.
    METHODS get_zip
      RETURNING VALUE(rv_zip) TYPE xstring.
  PRIVATE SECTION.
    DATA mo_zip TYPE REF TO cl_abap_zip.
ENDCLASS.

CLASS lcl_zip_writer IMPLEMENTATION.
  METHOD add_file.
    DATA lv_xstring TYPE xstring.

    IF iv_name IS INITIAL.
      RETURN.
    ENDIF.

    IF iv_content IS INITIAL.
      RETURN.
    ENDIF.

    IF mo_zip IS INITIAL.
      CREATE OBJECT mo_zip.
    ENDIF.

    lv_xstring = cl_abap_codepage=>convert_to( iv_content ).

    mo_zip->add(
      name    = iv_name
      content = lv_xstring ).
  ENDMETHOD.

  METHOD get_zip.
    CLEAR rv_zip.

    IF mo_zip IS INITIAL.
      RETURN.
    ENDIF.

    rv_zip = mo_zip->save( ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_logger DEFINITION.
  PUBLIC SECTION.
    METHODS add_success
      IMPORTING iv_object  TYPE trobjtype
                iv_name    TYPE sobj_name
                iv_message TYPE string.
    METHODS add_warning
      IMPORTING iv_object  TYPE trobjtype
                iv_name    TYPE sobj_name
                iv_message TYPE string.
    METHODS add_error
      IMPORTING iv_object  TYPE trobjtype
                iv_name    TYPE sobj_name
                iv_message TYPE string.
    METHODS add_info
      IMPORTING iv_object  TYPE trobjtype
                iv_name    TYPE sobj_name
                iv_message TYPE string.
    METHODS to_string
      RETURNING VALUE(rv_text) TYPE string.
    METHODS summary_to_string
      RETURNING VALUE(rv_text) TYPE string.
  PRIVATE SECTION.
    DATA mt_log TYPE tt_log.
    DATA mv_success TYPE i.
    DATA mv_warning TYPE i.
    DATA mv_error   TYPE i.
    DATA mv_info    TYPE i.
    METHODS add_entry
      IMPORTING iv_status  TYPE c
                iv_object  TYPE trobjtype
                iv_name    TYPE sobj_name
                iv_message TYPE string.
ENDCLASS.

CLASS lcl_logger IMPLEMENTATION.
  METHOD add_entry.
    DATA ls_log TYPE ty_log.

    CLEAR ls_log.
    ls_log-status   = iv_status.
    ls_log-object   = iv_object.
    ls_log-obj_name = iv_name.
    ls_log-message  = iv_message.
    APPEND ls_log TO mt_log.

    CASE iv_status.
      WHEN 'S'.
        mv_success = mv_success + 1.
      WHEN 'W'.
        mv_warning = mv_warning + 1.
      WHEN 'E'.
        mv_error = mv_error + 1.
      WHEN OTHERS.
        mv_info = mv_info + 1.
    ENDCASE.
  ENDMETHOD.

  METHOD add_success.
    add_entry(
      EXPORTING
        iv_status  = 'S'
        iv_object  = iv_object
        iv_name    = iv_name
        iv_message = iv_message ).
  ENDMETHOD.

  METHOD add_warning.
    add_entry(
      EXPORTING
        iv_status  = 'W'
        iv_object  = iv_object
        iv_name    = iv_name
        iv_message = iv_message ).
  ENDMETHOD.

  METHOD add_error.
    add_entry(
      EXPORTING
        iv_status  = 'E'
        iv_object  = iv_object
        iv_name    = iv_name
        iv_message = iv_message ).
  ENDMETHOD.

  METHOD add_info.
    add_entry(
      EXPORTING
        iv_status  = 'I'
        iv_object  = iv_object
        iv_name    = iv_name
        iv_message = iv_message ).
  ENDMETHOD.

  METHOD to_string.
    DATA ls_log TYPE ty_log.
    DATA lv_line TYPE string.

    CLEAR rv_text.

    LOOP AT mt_log INTO ls_log.
      CLEAR lv_line.
      CONCATENATE ls_log-status
                  ls_log-object
                  ls_log-obj_name
                  ls_log-message
             INTO lv_line
             SEPARATED BY space.

      lcl_text=>append_line(
        EXPORTING
          iv_line = lv_line
        CHANGING
          cv_text = rv_text ).
    ENDLOOP.
  ENDMETHOD.

  METHOD summary_to_string.
    DATA lv_line TYPE string.

    CLEAR rv_text.

    CONCATENATE 'Package:' p_pack INTO lv_line SEPARATED BY space.
    lcl_text=>append_line(
      EXPORTING
        iv_line = lv_line
      CHANGING
        cv_text = rv_text ).

    CLEAR lv_line.
    CONCATENATE 'Successful exports:' mv_success INTO lv_line SEPARATED BY space.
    lcl_text=>append_line(
      EXPORTING
        iv_line = lv_line
      CHANGING
        cv_text = rv_text ).

    CLEAR lv_line.
    CONCATENATE 'Warnings:' mv_warning INTO lv_line SEPARATED BY space.
    lcl_text=>append_line(
      EXPORTING
        iv_line = lv_line
      CHANGING
        cv_text = rv_text ).

    CLEAR lv_line.
    CONCATENATE 'Errors:' mv_error INTO lv_line SEPARATED BY space.
    lcl_text=>append_line(
      EXPORTING
        iv_line = lv_line
      CHANGING
        cv_text = rv_text ).

    CLEAR lv_line.
    CONCATENATE 'Info:' mv_info INTO lv_line SEPARATED BY space.
    lcl_text=>append_line(
      EXPORTING
        iv_line = lv_line
      CHANGING
        cv_text = rv_text ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_source_reader DEFINITION.
  PUBLIC SECTION.
    METHODS read_report_safe
      IMPORTING iv_prog TYPE progname
      EXPORTING et_source TYPE tt_source
                ev_found  TYPE abap_bool.
    METHODS get_all_includes
      IMPORTING iv_prog TYPE progname
      RETURNING VALUE(rt_includes) TYPE tt_progname.
    METHODS build_class_part_program
      IMPORTING iv_class  TYPE seoclsname
                iv_suffix TYPE char10
      RETURNING VALUE(rv_prog) TYPE progname.
ENDCLASS.

CLASS lcl_source_reader IMPLEMENTATION.
  METHOD read_report_safe.
    CLEAR et_source.
    CLEAR ev_found.

    READ REPORT iv_prog INTO et_source.
    IF sy-subrc = 0 AND et_source IS NOT INITIAL.
      ev_found = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD get_all_includes.
    DATA lv_include TYPE progname.

    CLEAR rt_includes.

    CALL FUNCTION 'RS_GET_ALL_INCLUDES'
      EXPORTING
        program    = iv_prog
      TABLES
        includetab = rt_includes
      EXCEPTIONS
        OTHERS     = 1.

    SORT rt_includes BY table_line.
    DELETE ADJACENT DUPLICATES FROM rt_includes COMPARING table_line.

    DELETE rt_includes WHERE table_line IS INITIAL.

    LOOP AT rt_includes INTO lv_include.
      IF lv_include = iv_prog.
        DELETE rt_includes.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_class_part_program.
    CONCATENATE iv_class '==========' iv_suffix INTO rv_prog.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_ddic_exporter DEFINITION.
  PUBLIC SECTION.
    METHODS get_table_text
      IMPORTING iv_tabname TYPE tabname
      EXPORTING ev_text    TYPE string
                ev_found   TYPE abap_bool.
    METHODS get_view_text
      IMPORTING iv_viewname TYPE tabname
      EXPORTING ev_text     TYPE string
                ev_found    TYPE abap_bool.
ENDCLASS.

CLASS lcl_ddic_exporter IMPLEMENTATION.
  METHOD get_table_text.
    DATA ls_dd02v TYPE dd02v.
    DATA ls_dd09l TYPE dd09l.
    DATA lt_dd03p TYPE STANDARD TABLE OF dd03p WITH DEFAULT KEY.
    DATA ls_dd03p TYPE dd03p.
    DATA lt_dd05m TYPE STANDARD TABLE OF dd05m WITH DEFAULT KEY.
    DATA ls_dd05m TYPE dd05m.
    DATA lt_dd08v TYPE STANDARD TABLE OF dd08v WITH DEFAULT KEY.
    DATA ls_dd08v TYPE dd08v.
    DATA lt_dd12v TYPE STANDARD TABLE OF dd12v WITH DEFAULT KEY.
    DATA ls_dd12v TYPE dd12v.
    DATA lt_dd17v TYPE STANDARD TABLE OF dd17v WITH DEFAULT KEY.
    DATA ls_dd17v TYPE dd17v.
    DATA lv_line  TYPE string.

    CLEAR ev_text.
    CLEAR ev_found.

    CALL FUNCTION 'DDIF_TABL_GET'
      EXPORTING
        name      = iv_tabname
        langu     = sy-langu
      IMPORTING
        dd02v_wa  = ls_dd02v
        dd09l_wa  = ls_dd09l
      TABLES
        dd03p_tab = lt_dd03p
        dd05m_tab = lt_dd05m
        dd08v_tab = lt_dd08v
        dd12v_tab = lt_dd12v
        dd17v_tab = lt_dd17v
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ev_found = abap_true.

    CONCATENATE 'OBJECT TYPE: TABLE'
                'NAME:'
                iv_tabname
           INTO lv_line
           SEPARATED BY space.
    lcl_text=>append_line(
      EXPORTING
        iv_line = lv_line
      CHANGING
        cv_text = ev_text ).

    CLEAR lv_line.
    CONCATENATE 'TABCLASS:' ls_dd02v-tabclass
                'CONTFLAG:' ls_dd02v-contflag
                'DDLANGUAGE:' ls_dd02v-ddlanguage
           INTO lv_line
           SEPARATED BY space.
    lcl_text=>append_line(
      EXPORTING
        iv_line = lv_line
      CHANGING
        cv_text = ev_text ).

    CLEAR lv_line.
    CONCATENATE 'DELIVERY CLASS:' ls_dd02v-contflag
                'AUTHCLASS:' ls_dd02v-authclass
           INTO lv_line
           SEPARATED BY space.
    lcl_text=>append_line(
      EXPORTING
        iv_line = lv_line
      CHANGING
        cv_text = ev_text ).

    lcl_text=>append_line(
      EXPORTING
        iv_line = 'TECHNICAL SETTINGS:'
      CHANGING
        cv_text = ev_text ).

    CLEAR lv_line.
    CONCATENATE 'BUFFERED:' ls_dd09l-bufallow
                'BUFFERING TYPE:' ls_dd09l-buftype
                'LOGGING:' ls_dd09l-protokoll
           INTO lv_line
           SEPARATED BY space.
    lcl_text=>append_line(
      EXPORTING
        iv_line = lv_line
      CHANGING
        cv_text = ev_text ).

    lcl_text=>append_line(
      EXPORTING
        iv_line = 'FIELDS:'
      CHANGING
        cv_text = ev_text ).

    LOOP AT lt_dd03p INTO ls_dd03p.
      CLEAR lv_line.
      CONCATENATE ls_dd03p-position
                  ls_dd03p-keyflag
                  ls_dd03p-fieldname
                  ls_dd03p-rollname
                  ls_dd03p-datatype
                  ls_dd03p-leng
                  ls_dd03p-decimals
             INTO lv_line
             SEPARATED BY space.

      lcl_text=>append_line(
        EXPORTING
          iv_line = lv_line
        CHANGING
          cv_text = ev_text ).
    ENDLOOP.

    IF lt_dd12v IS NOT INITIAL.
      lcl_text=>append_line(
        EXPORTING
          iv_line = 'INDEXES:'
        CHANGING
          cv_text = ev_text ).

      LOOP AT lt_dd12v INTO ls_dd12v.
        CLEAR lv_line.
        CONCATENATE ls_dd12v-indexname
                    ls_dd12v-sqltab
                    ls_dd12v-dbstate
               INTO lv_line
               SEPARATED BY space.
        lcl_text=>append_line(
          EXPORTING
            iv_line = lv_line
          CHANGING
            cv_text = ev_text ).
      ENDLOOP.

      LOOP AT lt_dd17v INTO ls_dd17v.
        CLEAR lv_line.
        CONCATENATE 'INDEX FIELD:'
                    ls_dd17v-indexname
                    ls_dd17v-fieldname
                    ls_dd17v-position
               INTO lv_line
               SEPARATED BY space.
        lcl_text=>append_line(
          EXPORTING
            iv_line = lv_line
          CHANGING
            cv_text = ev_text ).
      ENDLOOP.
    ENDIF.

    IF lt_dd08v IS NOT INITIAL OR lt_dd05m IS NOT INITIAL.
      lcl_text=>append_line(
        EXPORTING
          iv_line = 'FOREIGN KEYS:'
        CHANGING
          cv_text = ev_text ).

      LOOP AT lt_dd08v INTO ls_dd08v.
        CLEAR lv_line.
        CONCATENATE ls_dd08v-fieldname
                    ls_dd08v-checktable
                    ls_dd08v-frkart
               INTO lv_line
               SEPARATED BY space.
        lcl_text=>append_line(
          EXPORTING
            iv_line = lv_line
          CHANGING
            cv_text = ev_text ).
      ENDLOOP.

      LOOP AT lt_dd05m INTO ls_dd05m.
        CLEAR lv_line.
        CONCATENATE 'FK FIELD MAPPING:'
                    ls_dd05m-fieldname
                    ls_dd05m-checkfield
               INTO lv_line
               SEPARATED BY space.
        lcl_text=>append_line(
          EXPORTING
            iv_line = lv_line
          CHANGING
            cv_text = ev_text ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD get_view_text.
    DATA ls_dd25v TYPE dd25v.
    DATA lt_dd26v TYPE STANDARD TABLE OF dd26v WITH DEFAULT KEY.
    DATA ls_dd26v TYPE dd26v.
    DATA lt_dd27p TYPE STANDARD TABLE OF dd27p WITH DEFAULT KEY.
    DATA ls_dd27p TYPE dd27p.
    DATA lv_line TYPE string.

    CLEAR ev_text.
    CLEAR ev_found.

    CALL FUNCTION 'DDIF_VIEW_GET'
      EXPORTING
        name      = iv_viewname
        state     = 'A'
        langu     = sy-langu
      IMPORTING
        dd25v_wa  = ls_dd25v
      TABLES
        dd26v_tab = lt_dd26v
        dd27p_tab = lt_dd27p
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ev_found = abap_true.

    CONCATENATE 'OBJECT TYPE: VIEW'
                'NAME:'
                iv_viewname
           INTO lv_line
           SEPARATED BY space.
    lcl_text=>append_line(
      EXPORTING
        iv_line = lv_line
      CHANGING
        cv_text = ev_text ).

    CLEAR lv_line.
    CONCATENATE 'VIEW CLASS:' ls_dd25v-viewclass
                'ROOT TABLE:' ls_dd25v-roottab
           INTO lv_line
           SEPARATED BY space.
    lcl_text=>append_line(
      EXPORTING
        iv_line = lv_line
      CHANGING
        cv_text = ev_text ).

    IF lt_dd26v IS NOT INITIAL.
      lcl_text=>append_line(
        EXPORTING
          iv_line = 'VIEW TABLES:'
        CHANGING
          cv_text = ev_text ).

      LOOP AT lt_dd26v INTO ls_dd26v.
        CLEAR lv_line.
        CONCATENATE ls_dd26v-tabname
                    ls_dd26v-tabpos
               INTO lv_line
               SEPARATED BY space.
        lcl_text=>append_line(
          EXPORTING
            iv_line = lv_line
          CHANGING
            cv_text = ev_text ).
      ENDLOOP.
    ENDIF.

    IF lt_dd27p IS NOT INITIAL.
      lcl_text=>append_line(
        EXPORTING
          iv_line = 'VIEW FIELDS:'
        CHANGING
          cv_text = ev_text ).

      LOOP AT lt_dd27p INTO ls_dd27p.
        CLEAR lv_line.
        CONCATENATE ls_dd27p-viewfield
                    ls_dd27p-tabname
                    ls_dd27p-fieldname
                    ls_dd27p-keyflag
               INTO lv_line
               SEPARATED BY space.
        lcl_text=>append_line(
          EXPORTING
            iv_line = lv_line
          CHANGING
            cv_text = ev_text ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_exporter DEFINITION.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_zip    TYPE REF TO lcl_zip_writer
                io_source TYPE REF TO lcl_source_reader
                io_ddic   TYPE REF TO lcl_ddic_exporter
                io_log    TYPE REF TO lcl_logger.
    METHODS export_object
      IMPORTING is_tadir TYPE ty_tadir.
  PRIVATE SECTION.
    DATA mo_zip    TYPE REF TO lcl_zip_writer.
    DATA mo_source TYPE REF TO lcl_source_reader.
    DATA mo_ddic   TYPE REF TO lcl_ddic_exporter.
    DATA mo_log    TYPE REF TO lcl_logger.

    METHODS export_prog
      IMPORTING iv_prog TYPE progname.
    METHODS export_class
      IMPORTING iv_class TYPE seoclsname.
    METHODS export_fugr
      IMPORTING iv_fugr TYPE rs38l_area.
    METHODS export_table
      IMPORTING iv_tabname TYPE tabname.
    METHODS export_view
      IMPORTING iv_viewname TYPE tabname.
    METHODS add_report_to_zip
      IMPORTING iv_report   TYPE progname
                iv_zip_name TYPE string
      RETURNING VALUE(rv_found) TYPE abap_bool.
ENDCLASS.

CLASS lcl_exporter IMPLEMENTATION.
  METHOD constructor.
    mo_zip    = io_zip.
    mo_source = io_source.
    mo_ddic   = io_ddic.
    mo_log    = io_log.
  ENDMETHOD.

  METHOD add_report_to_zip.
    DATA lt_source TYPE tt_source.
    DATA lv_found  TYPE abap_bool.
    DATA lv_text   TYPE string.

    CLEAR rv_found.

    mo_source->read_report_safe(
      EXPORTING
        iv_prog   = iv_report
      IMPORTING
        et_source = lt_source
        ev_found  = lv_found ).

    IF lv_found IS INITIAL.
      RETURN.
    ENDIF.

    lv_text = lcl_text=>source_to_string( lt_source ).

    IF lv_text IS INITIAL.
      RETURN.
    ENDIF.

    mo_zip->add_file(
      iv_name    = iv_zip_name
      iv_content = lv_text ).

    rv_found = abap_true.
  ENDMETHOD.

  METHOD export_prog.
    DATA lt_includes TYPE tt_progname.
    DATA lv_include  TYPE progname.
    DATA lv_zip_name TYPE string.
    DATA lv_count    TYPE i.
    DATA lv_found    TYPE abap_bool.

    CLEAR lv_count.

    CONCATENATE 'src/prog/' iv_prog '/main.abap' INTO lv_zip_name.
    lv_found = add_report_to_zip(
      iv_report   = iv_prog
      iv_zip_name = lv_zip_name ).
    IF lv_found = abap_true.
      lv_count = lv_count + 1.
    ELSE.
      mo_log->add_warning(
        iv_object  = 'PROG'
        iv_name    = iv_prog
        iv_message = 'Main program source not found' ).
    ENDIF.

    lt_includes = mo_source->get_all_includes( iv_prog ).

    LOOP AT lt_includes INTO lv_include.
      CLEAR lv_zip_name.
      CONCATENATE 'src/prog/' iv_prog '/includes/' lv_include '.abap'
             INTO lv_zip_name.

      lv_found = add_report_to_zip(
        iv_report   = lv_include
        iv_zip_name = lv_zip_name ).

      IF lv_found = abap_true.
        lv_count = lv_count + 1.
      ELSE.
        mo_log->add_warning(
          iv_object  = 'PROG'
          iv_name    = iv_prog
          iv_message = 'Include listed but source not readable' ).
      ENDIF.
    ENDLOOP.

    IF lv_count > 0.
      mo_log->add_success(
        iv_object  = 'PROG'
        iv_name    = iv_prog
        iv_message = 'Program exported' ).
    ELSE.
      mo_log->add_error(
        iv_object  = 'PROG'
        iv_name    = iv_prog
        iv_message = 'No program content exported' ).
    ENDIF.
  ENDMETHOD.

  METHOD export_class.
    DATA lv_prog     TYPE progname.
    DATA lv_zip_name TYPE string.
    DATA lv_count    TYPE i.
    DATA lv_found    TYPE abap_bool.

    CLEAR lv_count.

    lv_prog = mo_source->build_class_part_program(
      iv_class  = iv_class
      iv_suffix = 'CP' ).
    CONCATENATE 'src/clas/' iv_class '/cp.abap' INTO lv_zip_name.
    lv_found = add_report_to_zip(
      iv_report   = lv_prog
      iv_zip_name = lv_zip_name ).
    IF lv_found = abap_true.
      lv_count = lv_count + 1.
    ENDIF.

    lv_prog = mo_source->build_class_part_program(
      iv_class  = iv_class
      iv_suffix = 'CCDEF' ).
    CONCATENATE 'src/clas/' iv_class '/ccdef.abap' INTO lv_zip_name.
    lv_found = add_report_to_zip(
      iv_report   = lv_prog
      iv_zip_name = lv_zip_name ).
    IF lv_found = abap_true.
      lv_count = lv_count + 1.
    ENDIF.

    lv_prog = mo_source->build_class_part_program(
      iv_class  = iv_class
      iv_suffix = 'CCIMP' ).
    CONCATENATE 'src/clas/' iv_class '/ccimp.abap' INTO lv_zip_name.
    lv_found = add_report_to_zip(
      iv_report   = lv_prog
      iv_zip_name = lv_zip_name ).
    IF lv_found = abap_true.
      lv_count = lv_count + 1.
    ENDIF.

    lv_prog = mo_source->build_class_part_program(
      iv_class  = iv_class
      iv_suffix = 'CCMAC' ).
    CONCATENATE 'src/clas/' iv_class '/ccmac.abap' INTO lv_zip_name.
    lv_found = add_report_to_zip(
      iv_report   = lv_prog
      iv_zip_name = lv_zip_name ).
    IF lv_found = abap_true.
      lv_count = lv_count + 1.
    ENDIF.

    lv_prog = mo_source->build_class_part_program(
      iv_class  = iv_class
      iv_suffix = 'CCAU' ).
    CONCATENATE 'src/clas/' iv_class '/ccau.abap' INTO lv_zip_name.
    lv_found = add_report_to_zip(
      iv_report   = lv_prog
      iv_zip_name = lv_zip_name ).
    IF lv_found = abap_true.
      lv_count = lv_count + 1.
    ENDIF.

    IF lv_count > 0.
      mo_log->add_success(
        iv_object  = 'CLAS'
        iv_name    = iv_class
        iv_message = 'Class exported' ).
    ELSE.
      mo_log->add_error(
        iv_object  = 'CLAS'
        iv_name    = iv_class
        iv_message = 'No class pool parts exported' ).
    ENDIF.
  ENDMETHOD.

  METHOD export_fugr.
    DATA lv_main_prog TYPE progname.
    DATA lt_includes  TYPE tt_progname.
    DATA lv_include   TYPE progname.
    DATA lt_enlfdir   TYPE tt_enlfdir.
    DATA ls_enlfdir   TYPE ty_enlfdir.
    DATA lv_zip_name  TYPE string.
    DATA lv_text      TYPE string.
    DATA lv_line      TYPE string.
    DATA lv_count     TYPE i.
    DATA lv_found     TYPE abap_bool.

    CLEAR lv_count.

    CONCATENATE 'SAPL' iv_fugr INTO lv_main_prog.
    CONCATENATE 'src/fugr/' iv_fugr '/main.abap' INTO lv_zip_name.

    lv_found = add_report_to_zip(
      iv_report   = lv_main_prog
      iv_zip_name = lv_zip_name ).
    IF lv_found = abap_true.
      lv_count = lv_count + 1.
    ELSE.
      mo_log->add_warning(
        iv_object  = 'FUGR'
        iv_name    = iv_fugr
        iv_message = 'Main function group program not found' ).
    ENDIF.

    lt_includes = mo_source->get_all_includes( lv_main_prog ).

    LOOP AT lt_includes INTO lv_include.
      CLEAR lv_zip_name.
      CONCATENATE 'src/fugr/' iv_fugr '/includes/' lv_include '.abap'
             INTO lv_zip_name.

      lv_found = add_report_to_zip(
        iv_report   = lv_include
        iv_zip_name = lv_zip_name ).

      IF lv_found = abap_true.
        lv_count = lv_count + 1.
      ENDIF.
    ENDLOOP.

    CLEAR lt_enlfdir.
    SELECT funcname include
      FROM enlfdir
      INTO TABLE lt_enlfdir
      WHERE area = iv_fugr.

    IF sy-subrc = 0 AND lt_enlfdir IS NOT INITIAL.
      SORT lt_enlfdir BY funcname.
      CLEAR lv_text.
      lcl_text=>append_line(
        EXPORTING
          iv_line = 'FUNCTION MODULES:'
        CHANGING
          cv_text = lv_text ).

      LOOP AT lt_enlfdir INTO ls_enlfdir.
        CLEAR lv_line.
        CONCATENATE ls_enlfdir-funcname
                    ls_enlfdir-include
               INTO lv_line
               SEPARATED BY space.
        lcl_text=>append_line(
          EXPORTING
            iv_line = lv_line
          CHANGING
            cv_text = lv_text ).
      ENDLOOP.

      CONCATENATE 'src/fugr/' iv_fugr '/function_modules.txt'
             INTO lv_zip_name.
      mo_zip->add_file(
        iv_name    = lv_zip_name
        iv_content = lv_text ).
    ENDIF.

    IF lv_count > 0.
      mo_log->add_success(
        iv_object  = 'FUGR'
        iv_name    = iv_fugr
        iv_message = 'Function group exported' ).
    ELSE.
      mo_log->add_error(
        iv_object  = 'FUGR'
        iv_name    = iv_fugr
        iv_message = 'No function group source exported' ).
    ENDIF.
  ENDMETHOD.

  METHOD export_table.
    DATA lv_text  TYPE string.
    DATA lv_found TYPE abap_bool.
    DATA lv_zip_name TYPE string.

    mo_ddic->get_table_text(
      EXPORTING
        iv_tabname = iv_tabname
      IMPORTING
        ev_text    = lv_text
        ev_found   = lv_found ).

    IF lv_found IS INITIAL.
      mo_log->add_error(
        iv_object  = 'TABL'
        iv_name    = iv_tabname
        iv_message = 'DDIC table metadata not found' ).
      RETURN.
    ENDIF.

    CONCATENATE 'src/ddic/tabl/' iv_tabname '.txt' INTO lv_zip_name.
    mo_zip->add_file(
      iv_name    = lv_zip_name
      iv_content = lv_text ).

    mo_log->add_success(
      iv_object  = 'TABL'
      iv_name    = iv_tabname
      iv_message = 'DDIC table exported' ).
  ENDMETHOD.

  METHOD export_view.
    DATA lv_text  TYPE string.
    DATA lv_found TYPE abap_bool.
    DATA lv_zip_name TYPE string.

    mo_ddic->get_view_text(
      EXPORTING
        iv_viewname = iv_viewname
      IMPORTING
        ev_text     = lv_text
        ev_found    = lv_found ).

    IF lv_found IS INITIAL.
      mo_log->add_error(
        iv_object  = 'VIEW'
        iv_name    = iv_viewname
        iv_message = 'DDIC view metadata not found' ).
      RETURN.
    ENDIF.

    CONCATENATE 'src/ddic/view/' iv_viewname '.txt' INTO lv_zip_name.
    mo_zip->add_file(
      iv_name    = lv_zip_name
      iv_content = lv_text ).

    mo_log->add_success(
      iv_object  = 'VIEW'
      iv_name    = iv_viewname
      iv_message = 'DDIC view exported' ).
  ENDMETHOD.

  METHOD export_object.
    CASE is_tadir-object.
      WHEN 'PROG'.
        export_prog( is_tadir-obj_name ).

      WHEN 'CLAS'.
        export_class( is_tadir-obj_name ).

      WHEN 'FUGR'.
        export_fugr( is_tadir-obj_name ).

      WHEN 'TABL'.
        export_table( is_tadir-obj_name ).

      WHEN 'VIEW'.
        export_view( is_tadir-obj_name ).

      WHEN 'INTF' OR 'DDLS' OR 'ENHO' OR 'ENHS' OR 'SXSD' OR 'SXCI'.
        mo_log->add_info(
          iv_object  = is_tadir-object
          iv_name    = is_tadir-obj_name
          iv_message = 'Object type detected but not exported by this report version' ).

      WHEN OTHERS.
        mo_log->add_info(
          iv_object  = is_tadir-object
          iv_name    = is_tadir-obj_name
          iv_message = 'Unsupported object type skipped' ).
    ENDCASE.
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.

  DATA lt_tadir TYPE tt_tadir.
  DATA ls_tadir TYPE ty_tadir.
  DATA lo_zip TYPE REF TO lcl_zip_writer.
  DATA lo_source TYPE REF TO lcl_source_reader.
  DATA lo_ddic TYPE REF TO lcl_ddic_exporter.
  DATA lo_log TYPE REF TO lcl_logger.
  DATA lo_exporter TYPE REF TO lcl_exporter.
  DATA lv_zip TYPE xstring.
  DATA lt_bin TYPE STANDARD TABLE OF x255 WITH DEFAULT KEY.
  DATA lv_size TYPE i.
  DATA lv_total TYPE i.
  DATA lv_index TYPE i.
  DATA lv_pct TYPE i.
  DATA lv_text TYPE string.

  CREATE OBJECT lo_zip.
  CREATE OBJECT lo_source.
  CREATE OBJECT lo_ddic.
  CREATE OBJECT lo_log.
  CREATE OBJECT lo_exporter
    EXPORTING
      io_zip    = lo_zip
      io_source = lo_source
      io_ddic   = lo_ddic
      io_log    = lo_log.

  SELECT object obj_name
    FROM tadir
    INTO TABLE lt_tadir
    WHERE pgmid    = 'R3TR'
      AND devclass = p_pack
    ORDER BY object obj_name.

  IF lt_tadir IS INITIAL.
    WRITE: / 'No repository objects found for package', p_pack.
    RETURN.
  ENDIF.

  DESCRIBE TABLE lt_tadir LINES lv_total.

  LOOP AT lt_tadir INTO ls_tadir.
    lv_index = sy-tabix.

    IF lv_total > 0.
      lv_pct = lv_index * 100 / lv_total.
      CLEAR lv_text.
      CONCATENATE 'Exporting'
                  ls_tadir-object
                  ls_tadir-obj_name
                  '('
                  lv_index
                  '/'
                  lv_total
                  ')'
             INTO lv_text
             SEPARATED BY space.

      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING
          percentage = lv_pct
          text       = lv_text
        EXCEPTIONS
          OTHERS     = 1.
    ENDIF.

    lo_exporter->export_object( ls_tadir ).
  ENDLOOP.

  lo_zip->add_file(
    iv_name    = 'logs/export_log.txt'
    iv_content = lo_log->to_string( ) ).

  lo_zip->add_file(
    iv_name    = 'logs/export_summary.txt'
    iv_content = lo_log->summary_to_string( ) ).

  lv_zip = lo_zip->get_zip( ).

  IF lv_zip IS INITIAL.
    WRITE: / 'No content to export'.
    WRITE: / lo_log->summary_to_string( ).
    RETURN.
  ENDIF.

  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING
      buffer     = lv_zip
    TABLES
      binary_tab = lt_bin
    EXCEPTIONS
      failed     = 1
      OTHERS     = 2.

  IF sy-subrc <> 0.
    WRITE: / 'Failed to convert ZIP to binary'.
    RETURN.
  ENDIF.

  lv_size = xstrlen( lv_zip ).

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      filename     = p_path
      filetype     = 'BIN'
      bin_filesize = lv_size
    TABLES
      data_tab     = lt_bin
    EXCEPTIONS
      file_write_error        = 1
      no_batch                = 2
      gui_refuse_filetransfer = 3
      invalid_type            = 4
      no_authority            = 5
      unknown_error           = 6
      header_not_allowed      = 7
      separator_not_allowed   = 8
      filesize_not_allowed    = 9
      header_too_long         = 10
      dp_error_create         = 11
      dp_error_send           = 12
      dp_error_write          = 13
      unknown_dp_error        = 14
      access_denied           = 15
      dp_out_of_memory        = 16
      disk_full               = 17
      dp_timeout              = 18
      file_not_found          = 19
      dataprovider_exception  = 20
      control_flush_error     = 21
      OTHERS                  = 22.

  IF sy-subrc <> 0.
    WRITE: / 'ZIP created but download failed. Target path:', p_path.
    WRITE: / lo_log->summary_to_string( ).
    RETURN.
  ENDIF.

  WRITE: / 'Export completed successfully'.
  WRITE: / 'ZIP file:', p_path.
  WRITE: / lo_log->summary_to_string( ).
