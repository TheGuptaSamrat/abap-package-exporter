REPORT z_export_pkg_adt_text.

*----------------------------------------------------------------------*
* TYPES & EXCEPTIONS
*----------------------------------------------------------------------*
TYPES: ty_str_lines TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
TYPES: BEGIN OF ty_tadir_obj,
         object   TYPE tadir-object,
         obj_name TYPE tadir-obj_name,
         devclass TYPE tadir-devclass,
       END OF ty_tadir_obj.
TYPES: tt_tadir_obj TYPE STANDARD TABLE OF ty_tadir_obj WITH DEFAULT KEY.

CLASS lcx_export_error DEFINITION INHERITING FROM cx_static_check.
  PUBLIC SECTION.
    DATA mv_msg TYPE string.
    METHODS constructor IMPORTING iv_msg TYPE string.
    METHODS get_text REDEFINITION.
ENDCLASS.

*----------------------------------------------------------------------*
* CLASS DEFINITIONS
*----------------------------------------------------------------------*

CLASS lcl_file_writer DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS write_source
      IMPORTING iv_path TYPE string  it_lines TYPE ty_str_lines.
    CLASS-METHODS write_lines
      IMPORTING iv_path TYPE string  it_lines TYPE ty_str_lines.
    CLASS-METHODS ensure_path
      IMPORTING iv_path TYPE string.
  PRIVATE SECTION.
    CLASS-METHODS dir_of
      IMPORTING iv_path TYPE string RETURNING VALUE(rv_dir) TYPE string.
    CLASS-METHODS do_download
      IMPORTING iv_path TYPE string  it_lines TYPE ty_str_lines  iv_bin TYPE abap_bool.
ENDCLASS.

CLASS lcl_source_reader DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS read_include
      IMPORTING iv_name TYPE programm RETURNING VALUE(rt_lines) TYPE ty_str_lines.
    CLASS-METHODS write_prog
      IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
    CLASS-METHODS write_intf
      IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
    CLASS-METHODS write_class
      IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
    CLASS-METHODS write_fugr
      IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
    CLASS-METHODS write_type
      IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
  PRIVATE SECTION.
    CLASS-METHODS write_if_not_empty
      IMPORTING iv_path TYPE string  it_lines TYPE ty_str_lines.
ENDCLASS.

CLASS lcl_ddic_reader DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS write_tabl IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
    CLASS-METHODS write_dtel IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
    CLASS-METHODS write_doma IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
    CLASS-METHODS write_view IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
    CLASS-METHODS write_shlp IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
    CLASS-METHODS write_msag IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
    CLASS-METHODS write_enhs IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
    CLASS-METHODS write_ddls IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
    CLASS-METHODS write_ddlx IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
    CLASS-METHODS write_dcls IMPORTING iv_name TYPE sobj_name  iv_dir TYPE string.
  PRIVATE SECTION.
    CLASS-METHODS h1    IMPORTING iv_type TYPE string iv_name TYPE string CHANGING ct_out TYPE ty_str_lines.
    CLASS-METHODS attr  IMPORTING iv_label TYPE string iv_value TYPE string CHANGING ct_out TYPE ty_str_lines.
    CLASS-METHODS sep   CHANGING ct_out TYPE ty_str_lines.
    CLASS-METHODS blank CHANGING ct_out TYPE ty_str_lines.
ENDCLASS.

CLASS lcl_package_collector DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES tt_devclass TYPE STANDARD TABLE OF devclass WITH DEFAULT KEY.
    METHODS constructor IMPORTING iv_root TYPE devclass.
    METHODS collect      RAISING lcx_export_error.
    METHODS get_objects_for  IMPORTING iv_pack TYPE devclass RETURNING VALUE(rt_objs) TYPE tt_tadir_obj.
    METHODS get_children_of  IMPORTING iv_pack TYPE devclass RETURNING VALUE(rt_packs) TYPE tt_devclass.
    METHODS get_total_count  RETURNING VALUE(rv_n) TYPE i.
  PRIVATE SECTION.
    DATA mv_root    TYPE devclass.
    DATA mt_packs   TYPE tt_devclass.
    DATA mt_objects TYPE tt_tadir_obj.
    METHODS recurse IMPORTING iv_pack TYPE devclass.
ENDCLASS.

CLASS lcl_exporter DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS constructor IMPORTING iv_pack TYPE devclass iv_path TYPE string.
    METHODS run         RAISING lcx_export_error.
  PRIVATE SECTION.
    DATA mv_pack    TYPE devclass.
    DATA mv_base    TYPE string.
    DATA mo_coll    TYPE REF TO lcl_package_collector.
    DATA mv_done    TYPE i.
    DATA mv_total   TYPE i.
    METHODS process_package IMPORTING iv_pack TYPE devclass iv_folder TYPE string.
    METHODS process_object  IMPORTING is_obj TYPE ty_tadir_obj iv_src TYPE string.
    METHODS write_devc      IMPORTING iv_pack TYPE devclass iv_folder TYPE string.
    METHODS tick            IMPORTING iv_text TYPE string.
ENDCLASS.

*----------------------------------------------------------------------*
* CLASS IMPLEMENTATIONS
*----------------------------------------------------------------------*

CLASS lcx_export_error IMPLEMENTATION.
  METHOD constructor.
    super->constructor( ).
    mv_msg = iv_msg.
  ENDMETHOD.
  METHOD get_text.
    result = mv_msg.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_file_writer IMPLEMENTATION.
  METHOD dir_of.
    DATA(lv_off) = find( val = iv_path sub = '\' occ = -1 ).
    rv_dir = COND #( WHEN lv_off > 0 THEN iv_path(lv_off) ELSE '' ).
  ENDMETHOD.
  METHOD ensure_path.
    DATA(lv_dir) = dir_of( iv_path ).
    IF lv_dir IS NOT INITIAL.
      cl_gui_frontend_services=>directory_create( EXPORTING directory = lv_dir EXCEPTIONS directory_create_failed = 1 OTHERS = 2 ).
    ENDIF.
  ENDMETHOD.
  METHOD do_download.
    ensure_path( iv_path ).
    cl_gui_frontend_services=>gui_download(
      EXPORTING filename = iv_path filetype = COND #( WHEN iv_bin = abap_true THEN 'BIN' ELSE 'ASC' )
                codepage = '4110' trunc_trailing_blanks = abap_true
      CHANGING  data_tab = it_lines EXCEPTIONS OTHERS = 1 ).
  ENDMETHOD.
  METHOD write_source.
    do_download( iv_path = iv_path it_lines = it_lines iv_bin = abap_false ).
  ENDMETHOD.
  METHOD write_lines.
    do_download( iv_path = iv_path it_lines = it_lines iv_bin = abap_false ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_source_reader IMPLEMENTATION.
  METHOD read_include.
    READ REPORT iv_name INTO rt_lines.
    IF sy-subrc <> 0. CLEAR rt_lines. ENDIF.
  ENDMETHOD.
  METHOD write_if_not_empty.
    IF it_lines IS NOT INITIAL.
      lcl_file_writer=>write_source( iv_path = iv_path it_lines = it_lines ).
    ENDIF.
  ENDMETHOD.
  METHOD write_prog.
    DATA(lv_prog) = CONV programm( iv_name ).
    lcl_file_writer=>write_source( iv_path = iv_dir && iv_name && '.prog.abap' it_lines = read_include( lv_prog ) ).
  ENDMETHOD.
  METHOD write_intf.
    DATA(lv_name) = CONV clike( iv_name ).
    lcl_file_writer=>write_source( iv_path = iv_dir && iv_name && '.intf.abap' it_lines = read_include( cl_oo_classname_service=>get_intf_name( lv_name ) ) ).
  ENDMETHOD.
  METHOD write_class.
    DATA(lv_name) = CONV clike( iv_name ).
    write_if_not_empty( iv_path = iv_dir && iv_name && '.clas.abap'      it_lines = read_include( cl_oo_classname_service=>get_classpool_name( lv_name ) ) ).
    write_if_not_empty( iv_path = iv_dir && iv_name && '.clas.locals.abap' it_lines = read_include( cl_oo_classname_service=>get_ccdef_name( lv_name ) ) ).
    write_if_not_empty( iv_path = iv_dir && iv_name && '.clas.macros.abap' it_lines = read_include( cl_oo_classname_service=>get_ccmac_name( lv_name ) ) ).
    write_if_not_empty( iv_path = iv_dir && iv_name && '.clas.testclasses.abap' it_lines = read_include( cl_oo_classname_service=>get_ccau_name( lv_name ) ) ).
  ENDMETHOD.
  METHOD write_fugr.
    DATA(lv_name) = CONV clike( iv_name ).
    DATA(lv_pool) = cl_fuga_classname_service=>get_fugr_name( lv_name ).
    write_if_not_empty( iv_path = iv_dir && iv_name && '.fugr.abap' it_lines = read_include( lv_pool ) ).
    SELECT name FROM reposrc INTO TABLE @DATA(lt_incs) WHERE name LIKE @( lv_pool(3) && 'U%' ).
    LOOP AT lt_incs INTO DATA(ls_i).
      write_if_not_empty( iv_path = iv_dir && ls_i-name && '.abap' it_lines = read_include( ls_i-name ) ).
    ENDLOOP.
  ENDMETHOD.
  METHOD write_type.
    DATA(lv_prog) = CONV programm( iv_name ).
    lcl_file_writer=>write_source( iv_path = iv_dir && iv_name && '.type.abap' it_lines = read_include( lv_prog ) ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_ddic_reader IMPLEMENTATION.
  METHOD h1.
    APPEND |* ================================================================| TO ct_out.
    APPEND |* { iv_type }: { iv_name }|                                        TO ct_out.
    APPEND |* ================================================================| TO ct_out.
  ENDMETHOD.
  METHOD attr.
    APPEND |* { iv_label WIDTH = 22 ALIGN = LEFT PAD = ' ' } : { iv_value }| TO ct_out.
  ENDMETHOD.
  METHOD sep.
    APPEND |* { repeat( val = '-' occ = 72 ) }|                                TO ct_out.
  ENDMETHOD.
  METHOD blank.
    APPEND ||                                                                   TO ct_out.
  ENDMETHOD.

  METHOD write_tabl.
    DATA lt_out TYPE ty_str_lines.
    DATA lt_flds TYPE STANDARD TABLE OF dd03p WITH DEFAULT KEY.
    DATA ls_d02v TYPE dd02v.
    SELECT SINGLE tabclass, contflag, authclass, columnstore FROM dd02l INTO @DATA(ls_hdr) WHERE tabname = @iv_name AND as4local = 'A'.
    SELECT SINGLE ddtext FROM dd02t INTO @DATA(lv_ddtext) WHERE tabname = @iv_name AND ddlanguage = @sy-langu.
    h1( iv_type = 'TABLE' iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
    attr( iv_label = 'Description' iv_value = |{ lv_ddtext }| CHANGING ct_out = lt_out ).
    attr( iv_label = 'Storage'     iv_value = |{ COND #( WHEN ls_hdr-columnstore = 'X' THEN 'COLUMN STORE' ELSE 'ROW STORE' ) }| CHANGING ct_out = lt_out ).
    CALL FUNCTION 'DD_INT_TABL_GET' EXPORTING tabname = CONV tabname( iv_name ) langu = sy-langu IMPORTING dd02v_n = ls_d02v TABLES dd03p_n = lt_flds EXCEPTIONS OTHERS = 1.
    IF sy-subrc = 0 AND ls_d02v IS NOT INITIAL.
      CALL FUNCTION 'DD_TABL_EXPAND' EXPORTING dd02v_wa = ls_d02v mode = 46 prid = 0 TABLES dd03p_tab = lt_flds EXCEPTIONS OTHERS = 1.
    ENDIF.
    LOOP AT lt_flds INTO DATA(ls_f) WHERE adminfield = 0 AND fieldname(1) <> '.'.
      APPEND |* { ls_f-fieldname WIDTH = 25 } { ls_f-datatype WIDTH = 8 }{ ls_f-leng WIDTH = 6 }{ ls_f-ddtext }| TO lt_out.
    ENDLOOP.
    lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.tabl.txt' it_lines = lt_out ).
  ENDMETHOD.

  METHOD write_dtel.
    DATA lt_out TYPE ty_str_lines.
    SELECT SINGLE domname, datatype, leng FROM dd04v INTO @DATA(ls_v) WHERE rollname = @iv_name AND as4local = 'A'.
    SELECT SINGLE ddtext FROM dd04t INTO @DATA(ls_t) WHERE rollname = @iv_name AND ddlanguage = @sy-langu.
    h1( iv_type = 'DATA ELEMENT' iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
    attr( iv_label = 'Description' iv_value = |{ ls_t-ddtext }| CHANGING ct_out = lt_out ).
    attr( iv_label = 'Domain'      iv_value = |{ ls_v-domname }| CHANGING ct_out = lt_out ).
    lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.dtel.txt' it_lines = lt_out ).
  ENDMETHOD.

  METHOD write_doma.
    DATA lt_out TYPE ty_str_lines.
    SELECT SINGLE datatype, leng FROM dd01v INTO @DATA(ls_v) WHERE domname = @iv_name AND as4local = 'A'.
    SELECT SINGLE ddtext FROM dd01t INTO @DATA(lv_ddtext) WHERE domname = @iv_name AND ddlanguage = @sy-langu.
    h1( iv_type = 'DOMAIN' iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
    attr( iv_label = 'Description' iv_value = |{ lv_ddtext }| CHANGING ct_out = lt_out ).
    attr( iv_label = 'Data Type'   iv_value = |{ ls_v-datatype }| CHANGING ct_out = lt_out ).
    lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.doma.txt' it_lines = lt_out ).
  ENDMETHOD.

  METHOD write_view.
    DATA lt_out TYPE ty_str_lines.
    SELECT SINGLE ddtext FROM dd25t INTO @DATA(lv_ddtext) WHERE viewname = @iv_name AND ddlanguage = @sy-langu.
    h1( iv_type = 'VIEW' iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
    attr( iv_label = 'Description' iv_value = |{ lv_ddtext }| CHANGING ct_out = lt_out ).
    lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.view.txt' it_lines = lt_out ).
  ENDMETHOD.

  METHOD write_shlp.
    DATA lt_out TYPE ty_str_lines.
    SELECT SINGLE ddtext FROM dd30t INTO @DATA(lv_ddtext) WHERE shlpname = @iv_name AND ddlanguage = @sy-langu.
    h1( iv_type = 'SEARCH HELP' iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
    attr( iv_label = 'Description' iv_value = |{ lv_ddtext }| CHANGING ct_out = lt_out ).
    lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.shlp.txt' it_lines = lt_out ).
  ENDMETHOD.

  METHOD write_msag.
    DATA lt_out TYPE ty_str_lines.
    SELECT SINGLE stext FROM t100a INTO @DATA(lv_stext) WHERE arbgb = @iv_name.
    h1( iv_type = 'MESSAGE CLASS' iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
    attr( iv_label = 'Description'  iv_value = |{ lv_stext }| CHANGING ct_out = lt_out ).
    lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.msag.txt' it_lines = lt_out ).
  ENDMETHOD.

  METHOD write_enhs.
    DATA lt_out TYPE ty_str_lines.
    h1( iv_type = 'ENHANCEMENT SPOT' iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
    TRY.
        DATA(lo_spot) = cl_enh_factory=>get_enhancement_spot( spot_name = CONV enhspotname( iv_name ) ).
        APPEND |* Spot details read successfully.| TO lt_out.
      CATCH cx_enh_root INTO DATA(lx).
        APPEND |* Error: { lx->get_text( ) }| TO lt_out.
    ENDTRY.
    lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.enhs.txt' it_lines = lt_out ).
  ENDMETHOD.

  METHOD write_ddls.
    DATA lt_out TYPE ty_str_lines.
    SELECT SINGLE source FROM dddlsvrc INTO @DATA(lv_src) WHERE ddlname = @iv_name AND as4local = 'A'.
    IF sy-subrc = 0.
      APPEND lv_src TO lt_out.
      lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.ddls.asddls' it_lines = lt_out ).
    ENDIF.
  ENDMETHOD.
  METHOD write_ddlx.
    DATA lt_out TYPE ty_str_lines.
    SELECT SINGLE source FROM dddlxsvrc INTO @DATA(lv_src) WHERE ddlxname = @iv_name AND as4local = 'A'.
    IF sy-subrc = 0.
      APPEND lv_src TO lt_out.
      lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.ddlx.asddlxs' it_lines = lt_out ).
    ENDIF.
  ENDMETHOD.
  METHOD write_dcls.
    DATA lt_out TYPE ty_str_lines.
    SELECT SINGLE source FROM ddclsvrc INTO @DATA(lv_src) WHERE dclname = @iv_name AND as4local = 'A'.
    IF sy-subrc = 0.
      APPEND lv_src TO lt_out.
      lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.dcls.asdcls' it_lines = lt_out ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_package_collector IMPLEMENTATION.
  METHOD constructor.
    mv_root = iv_root.
  ENDMETHOD.
  METHOD collect.
    SELECT SINGLE devclass FROM tdevc INTO @DATA(lv_chk) WHERE devclass = @mv_root.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcx_export_error EXPORTING iv_msg = |Package '{ mv_root }' not found|.
    ENDIF.
    recurse( mv_root ).
    IF mt_packs IS NOT INITIAL.
      SELECT object, obj_name, devclass FROM tadir INTO TABLE @mt_objects FOR ALL ENTRIES IN @mt_packs WHERE devclass = @mt_packs-table_line AND pgmid = 'R3TR' AND delflag = @abap_false.
    ENDIF.
  ENDMETHOD.
  METHOD recurse.
    APPEND iv_pack TO mt_packs.
    SELECT devclass FROM tdevc INTO TABLE @DATA(lt_subs) WHERE parentcl = @iv_pack.
    LOOP AT lt_subs INTO DATA(ls_s).
      recurse( ls_s-devclass ).
    ENDLOOP.
  ENDMETHOD.
  METHOD get_objects_for.
    LOOP AT mt_objects INTO DATA(ls_o) WHERE devclass = @iv_pack.
      APPEND ls_o TO rt_objs.
    ENDLOOP.
  ENDMETHOD.
  METHOD get_children_of.
    SELECT devclass FROM tdevc INTO TABLE @rt_packs WHERE parentcl = @iv_pack.
  ENDMETHOD.
  METHOD get_total_count.
    rv_n = lines( mt_objects ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_exporter IMPLEMENTATION.
  METHOD constructor.
    mv_pack = iv_pack.
    mv_base = iv_path.
    IF mv_base+( strlen( mv_base ) - 1 )(1) <> '\'.
      mv_base = mv_base && '\'.
    ENDIF.
    CREATE OBJECT mo_coll EXPORTING iv_root = iv_pack.
  ENDMETHOD.
  METHOD tick.
    mv_done = mv_done + 1.
    cl_progress_indicator=>progress_indicate( i_text = iv_text i_processed = mv_done i_total = mv_total i_output_immediately = abap_true ).
  ENDMETHOD.
  METHOD run.
    mo_coll->collect( ).
    mv_total = mo_coll->get_total_count( ).
    process_package( iv_pack = mv_pack iv_folder = mv_base && mv_pack && '\' ).
  ENDMETHOD.
  METHOD write_devc.
    DATA lt_out TYPE ty_str_lines.
    SELECT SINGLE ctext FROM tdevc INTO @DATA(lv_txt) WHERE devclass = @iv_pack.
    APPEND |* PACKAGE: { iv_pack } - { lv_txt }| TO lt_out.
    lcl_file_writer=>write_lines( iv_path = iv_folder && iv_pack && '.devc.txt' it_lines = lt_out ).
  ENDMETHOD.
  METHOD process_package.
    write_devc( iv_pack = iv_pack iv_folder = iv_folder ).
    DATA(lv_src) = iv_folder && 'src\'.
    LOOP AT mo_coll->get_objects_for( iv_pack ) INTO DATA(ls_obj).
      tick( |{ ls_obj-object } { ls_obj-obj_name }| ).
      TRY.
          process_object( is_obj = ls_obj iv_src = lv_src ).
        CATCH cx_root.
      ENDTRY.
    ENDLOOP.
    LOOP AT mo_coll->get_children_of( iv_pack ) INTO DATA(lv_child).
      process_package( iv_pack = lv_child iv_folder = iv_folder && lv_child && '\' ).
    ENDLOOP.
  ENDMETHOD.
  METHOD process_object.
    CASE is_obj-object.
      WHEN 'CLAS'. lcl_source_reader=>write_class( iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'PROG'. lcl_source_reader=>write_prog(  iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'INTF'. lcl_source_reader=>write_intf(  iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'FUGR'. lcl_source_reader=>write_fugr(  iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'TYPE'. lcl_source_reader=>write_type(  iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'TABL'. lcl_ddic_reader=>write_tabl(    iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'DTEL'. lcl_ddic_reader=>write_dtel(    iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'DOMA'. lcl_ddic_reader=>write_doma(    iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'VIEW'. lcl_ddic_reader=>write_view(    iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'SHLP'. lcl_ddic_reader=>write_shlp(    iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'MSAG'. lcl_ddic_reader=>write_msag(    iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'ENHS'. lcl_ddic_reader=>write_enhs(    iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'DDLS'. lcl_ddic_reader=>write_ddls(    iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'DDLX'. lcl_ddic_reader=>write_ddlx(    iv_name = is_obj-obj_name iv_dir = iv_src ).
      WHEN 'DCLS'. lcl_ddic_reader=>write_dcls(    iv_name = is_obj-obj_name iv_dir = iv_src ).
    ENDCASE.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* SELECTION SCREEN
*----------------------------------------------------------------------*
PARAMETERS p_pack TYPE devclass OBLIGATORY.
PARAMETERS p_path TYPE string   OBLIGATORY LOWER CASE DEFAULT 'C:\temp\abap_export\'.

START-OF-SELECTION.
  TRY.
      NEW lcl_exporter( iv_pack = p_pack iv_path = p_path )->run( ).
      WRITE: / 'Export complete.'.
    CATCH lcx_export_error INTO DATA(lx).
      MESSAGE lx->get_text( ) TYPE 'E'.
  ENDTRY.
