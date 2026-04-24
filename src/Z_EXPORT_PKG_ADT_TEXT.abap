*&---------------------------------------------------------------------*
*& Report : Z_EXPORT_PACKAGE_SOURCE
*& Version : 2.0 - Direct folder download (no ZIP)
*& Release : ABAP 7.51 / HANA 2.00
*&
*& Key design (learned from Z_MASS_ABAP_DOWNLOAD reference):
*& . Each object written individually via GUI_DOWNLOAD FILETYPE='ASC'
*& . trunc_trailing_blanks='X' strips char255 padding at download layer
*& . No cl_abap_zip, no cl_abap_codepage, no xstring accumulation
*& . Content built as APPEND-only string tables (no && loops)
*& . DD_INT_TABL_GET + DD_TABL_EXPAND for full DDIC field expansion
*& . DD_DOMA_GET for domain fixed values
*& . Output folder is git-ready: git init + git push works directly
*&
*& Folder structure (mirrors ADT Package Explorer):
*& <base_path>\<PACK>\
*& <PACK>.devc.txt
*& src\
*& <PROG>.prog.abap
*& <INTF>.intf.abap
*& <CLAS>\
*& <CLAS>.clas.abap
*& <CLAS>.clas.locals_def.abap
*& <CLAS>.clas.locals_imp.abap
*& <CLAS>.clas.testclasses.abap
*& <FUGR>\
*& <FUGR>.fugr.abap (TOP include)
*& <FM>.fugr.func.abap (one per FM)
*& <TABL>.tabl.txt / <DTEL>.dtel.txt / <DOMA>.doma.txt
*& <VIEW>.view.txt / <SHLP>.shlp.txt / <MSAG>.msag.txt
*& <ENHS>.enhs.txt / <TYPE>.type.abap
*& <SUBPACK>\
*& <SUBPACK>.devc.txt
*& src\ ...
*&---------------------------------------------------------------------*
REPORT z_export_package_source.
*----------------------------------------------------------------------*
* GLOBAL TYPES
*----------------------------------------------------------------------*
TYPES: " char255 - only type that works reliably with READ REPORT in 7.51
ty_src_table TYPE STANDARD TABLE OF char255 WITH DEFAULT KEY,
" String table for manually assembled DDIC / metadata content
ty_str_lines TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
" TADIR object record
BEGIN OF ty_tadir_obj,
pgmid TYPE pgmid,
object TYPE trobjtype,
obj_name TYPE sobj_name,
devclass TYPE devclass,
END OF ty_tadir_obj,
tt_tadir_obj TYPE STANDARD TABLE OF ty_tadir_obj WITH DEFAULT KEY.
*----------------------------------------------------------------------*
* SELECTION SCREEN
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME.
PARAMETERS: p_pack TYPE devclass OBLIGATORY,
p_path TYPE string DEFAULT 'C:\SAP_Export\'.
SELECTION-SCREEN END OF BLOCK b1.
*----------------------------------------------------------------------*
* EXCEPTION
*----------------------------------------------------------------------*
CLASS lcx_export_error DEFINITION INHERITING FROM cx_static_check FINAL.
PUBLIC SECTION.
METHODS constructor IMPORTING iv_msg TYPE string.
METHODS get_text REDEFINITION.
PRIVATE SECTION.
DATA mv_msg TYPE string.
ENDCLASS.
CLASS lcx_export_error IMPLEMENTATION.
METHOD constructor.
super->constructor( ).
mv_msg = iv_msg.
ENDMETHOD.
METHOD get_text.
result = mv_msg.
ENDMETHOD.
ENDCLASS.
*----------------------------------------------------------------------*
* CLASS: LCL_FILE_WRITER
* Owns all filesystem interaction.
* write_source : for char255 tables from READ REPORT
* write_lines : for string tables of DDIC / metadata text
* Both call GUI_DOWNLOAD with FILETYPE='ASC' trunc_trailing_blanks='X'
*----------------------------------------------------------------------*
CLASS lcl_file_writer DEFINITION FINAL.
PUBLIC SECTION.
CLASS-METHODS write_source IMPORTING iv_path TYPE string it_lines TYPE ty_src_table.
CLASS-METHODS write_lines IMPORTING iv_path TYPE string it_lines TYPE ty_str_lines.
CLASS-METHODS ensure_path IMPORTING iv_dir TYPE string.
PRIVATE SECTION.
CLASS-METHODS dir_of IMPORTING iv_full_path TYPE string RETURNING VALUE(rv_dir) TYPE string.
CLASS-METHODS do_download IMPORTING iv_path TYPE string CHANGING ct_tab TYPE STANDARD TABLE.
ENDCLASS.
CLASS lcl_file_writer IMPLEMENTATION.
METHOD dir_of.
" Return everything up to and including the last backslash
DATA(lv_len) = strlen( iv_full_path ).
DO lv_len TIMES.
DATA(lv_pos) = lv_len - sy-index.
IF iv_full_path+lv_pos(1) = '\'.
rv_dir = iv_full_path+0(lv_pos) && '\'.
RETURN.
ENDIF.
ENDDO.
rv_dir = iv_full_path.
ENDMETHOD.
ENDMETHOD.
METHOD ensure_path.
" Create every level of the path (Windows mkdir does not create
" intermediate directories in one call).
DATA lt_parts TYPE ty_str_lines.
DATA lv_cur TYPE string.
SPLIT iv_dir AT '\' INTO TABLE lt_parts.
LOOP AT lt_parts INTO DATA(lv_part).
CHECK lv_part IS NOT INITIAL.
lv_cur = COND string( WHEN lv_cur IS INITIAL THEN lv_part && '\' ELSE lv_cur && lv_part && '\' ).
CL_GUI_FRONTEND_SERVICES=>DIRECTORY_CREATE( EXPORTING directory = lv_cur EXCEPTIONS directory_create_failed = 1 OTHERS = 2 ).
" Ignore sy-subrc - the directory may already exist
ENDLOOP.
ENDMETHOD.
METHOD do_download.
ensure_path( dir_of( iv_path ) ).
CL_GUI_FRONTEND_SERVICES=>GUI_DOWNLOAD( EXPORTING filename = iv_path filetype = 'ASC' trunc_trailing_blanks = abap_true CHANGING data_tab = ct_tab EXCEPTIONS file_write_error = 1 no_batch = 2 gui_refuse_filetransfer = 3 OTHERS = 4 ).
IF sy-subrc <> 0.
WRITE: / | WARNING: write failed for { iv_path } (subrc={ sy-subrc })|.
ENDIF.
ENDMETHOD.
METHOD write_source.
" Local copy needed because GUI_DOWNLOAD CHANGING expects a variable
DATA lt_local TYPE ty_src_table.
lt_local = it_lines.
do_download( EXPORTING iv_path = iv_path CHANGING ct_tab = lt_local ).
ENDMETHOD.
METHOD write_lines.
DATA lt_local TYPE ty_str_lines.
lt_local = it_lines.
do_download( EXPORTING iv_path = iv_path CHANGING ct_tab = lt_local ).
ENDMETHOD.
ENDCLASS.
*----------------------------------------------------------------------*
* CLASS: LCL_SOURCE_READER
* Reads ABAP source for code-based object types.
* READ REPORT -> ty_src_table (char255) -> GUI_DOWNLOAD ASC directly.
* No string conversion, no accumulation - zero encoding issues.
*----------------------------------------------------------------------*
CLASS lcl_source_reader DEFINITION FINAL.
PUBLIC SECTION.
" Low-level include reader
CLASS-METHODS read_include IMPORTING iv_prog TYPE programm RETURNING VALUE(rt_lines) TYPE ty_src_table.
" One method per object type; writes directly to disk
CLASS-METHODS write_prog IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
CLASS-METHODS write_intf IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
CLASS-METHODS write_class IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
CLASS-METHODS write_fugr IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
CLASS-METHODS write_type IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
PRIVATE SECTION.
CLASS-METHODS write_if_not_empty IMPORTING iv_path TYPE string it_src TYPE ty_src_table.
ENDCLASS.
CLASS lcl_source_reader IMPLEMENTATION.
METHOD read_include.
READ REPORT iv_prog INTO rt_lines.
" READ REPORT sets sy-subrc; caller decides what to do with empty result
ENDMETHOD.
METHOD write_if_not_empty.
CHECK it_src IS NOT INITIAL.
lcl_file_writer=>write_source( iv_path = iv_path it_lines = it_src ).
ENDMETHOD.
METHOD write_prog.
lcl_file_writer=>write_source( iv_path = iv_dir && iv_name && '.prog.abap' it_lines = read_include( CONV programm( iv_name ) ) ).
ENDMETHOD.
METHOD write_intf.
" Interface pool is stored as program with the interface name
lcl_file_writer=>write_source( iv_path = iv_dir && iv_name && '.intf.abap' it_lines = read_include( CONV programm( iv_name ) ) ).
ENDMETHOD.
METHOD write_class.
DATA(lv_cls) = CONV seoclsname( iv_name ).
DATA(lv_dir) = iv_dir && iv_name && '\'.
" -- Main pool (definition + implementation merged) -------------
lcl_file_writer=>write_source( iv_path = lv_dir && iv_name && '.clas.abap' it_lines = read_include( CONV programm( iv_name ) ) ).
" -- Local type definitions (====CCDEF include) -------------
TRY.
write_if_not_empty( iv_path = lv_dir && iv_name && '.clas.locals_def.abap' it_src = read_include( CONV programm( cl_oo_classname_service=>get_ccdef_name( lv_cls ) ) ) ).
CATCH cx_root.
ENDTRY.
" -- Local class implementations (====CCIMP include) ----------
TRY.
write_if_not_empty( iv_path = lv_dir && iv_name && '.clas.locals_imp.abap' it_src = read_include( CONV programm( cl_oo_classname_service=>get_ccimp_name( lv_cls ) ) ) ).
CATCH cx_root.
ENDTRY.
" -- Macro definitions (====CCMAC include) --------------------
TRY.
write_if_not_empty( iv_path = lv_dir && iv_name && '.clas.macros.abap' it_src = read_include( CONV programm( cl_oo_classname_service=>get_ccmac_name( lv_cls ) ) ) ).
CATCH cx_root.
ENDTRY.
" -- ABAP Unit test classes (====CCAU include) ---------------
TRY.
write_if_not_empty( iv_path = lv_dir && iv_name && '.clas.testclasses.abap' it_src = read_include( CONV programm( cl_oo_classname_service=>get_ccau_name( lv_cls ) ) ) ).
CATCH cx_root.
ENDTRY.
ENDMETHOD.
METHOD write_fugr.
DATA(lv_dir) = iv_dir && iv_name && '\'.
" -- TOP include: L<FUGR>TOP (global data / declarations) ------
lcl_file_writer=>write_source( iv_path = lv_dir && iv_name && '.fugr.abap' it_lines = read_include( CONV programm( |L{ iv_name }TOP| ) ) ).
" -- UXX include: L<FUGR>UXX (FM container - list only) --------
write_if_not_empty( iv_path = lv_dir && iv_name && '.fugr.uxx.abap' it_src = read_include( CONV programm( |L{ iv_name }UXX| ) ) ).
" -- Individual FMs via TFDIR-INCLUDE (confirmed working pattern) -
SELECT funcname, include FROM tfdir WHERE pname = @( |SAPL{ iv_name }| ) INTO TABLE @DATA(lt_fms).
LOOP AT lt_fms INTO DATA(ls_fm).
write_if_not_empty( iv_path = lv_dir && ls_fm-funcname && '.fugr.func.abap' it_src = read_include( CONV programm( ls_fm-include ) ) ).
ENDLOOP.
ENDMETHOD.
METHOD write_type.
" Type groups are stored as ABAP programs of type T
DATA lv_prog TYPE programm.
lv_prog = iv_name. " Assign via variable to avoid inline CONV issue
lcl_file_writer=>write_source( iv_path = iv_dir && iv_name && '.type.abap' it_lines = read_include( lv_prog ) ).
ENDMETHOD.
ENDCLASS.
*----------------------------------------------------------------------*
* CLASS: LCL_DDIC_READER
* Reads DDIC metadata and writes human-readable text files.
* Uses DD_INT_TABL_GET + DD_TABL_EXPAND (as Z_MASS_ABAP_DOWNLOAD does)
* and DD_DOMA_GET for domain fixed values.
* Content built with APPEND - never accumulated with &&.
*----------------------------------------------------------------------*
CLASS lcl_ddic_reader DEFINITION FINAL.
PUBLIC SECTION.
CLASS-METHODS write_tabl IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
CLASS-METHODS write_dtel IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
CLASS-METHODS write_doma IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
CLASS-METHODS write_view IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
CLASS-METHODS write_shlp IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
CLASS-METHODS write_msag IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
CLASS-METHODS write_enhs IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
CLASS-METHODS write_ddls IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
CLASS-METHODS write_ddlx IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
CLASS-METHODS write_dcls IMPORTING iv_name TYPE sobj_name iv_dir TYPE string.
PRIVATE SECTION.
" -- Small formatting helpers ----------------------------------
CLASS-METHODS h1 IMPORTING iv_type TYPE string iv_name TYPE string CHANGING ct_out TYPE ty_str_lines.
CLASS-METHODS attr IMPORTING iv_label TYPE string iv_value TYPE string CHANGING ct_out TYPE ty_str_lines.
CLASS-METHODS sep CHANGING ct_out TYPE ty_str_lines.
CLASS-METHODS blank CHANGING ct_out TYPE ty_str_lines.
ENDCLASS.
CLASS lcl_ddic_reader IMPLEMENTATION.
METHOD h1.
APPEND |* ================================================================| TO ct_out.
APPEND |* { iv_type }: { iv_name }| TO ct_out.
APPEND |* ================================================================| TO ct_out.
ENDMETHOD.
METHOD attr.
APPEND |* { iv_label WIDTH = 22 ALIGN = LEFT PAD = ' ' } : { iv_value }| TO ct_out.
ENDMETHOD.
METHOD sep.
APPEND |* { repeat( val = '-' occ = 72 ) }| TO ct_out.
ENDMETHOD.
METHOD blank.
APPEND || TO ct_out.
ENDMETHOD.
"--------------------------------------------------------------------------
" TABL / INTTAB - uses DD_INT_TABL_GET + DD_TABL_EXPAND (reference prog)
"--------------------------------------------------------------------------
METHOD write_tabl.
DATA lt_out TYPE ty_str_lines.
DATA lt_flds TYPE STANDARD TABLE OF dd03p WITH DEFAULT KEY.
DATA ls_d02l TYPE dd02l.
DATA ls_d02t TYPE dd02t.
DATA ls_d02v TYPE dd02v.
DATA lv_tab TYPE tabname.
lv_tab = iv_name.
SELECT SINGLE tabclass, contflag, authclass, columnstore FROM dd02l INTO @DATA(ls_hdr) WHERE tabname = @lv_tab AND as4local = 'A'.
SELECT SINGLE ddtext FROM dd02t INTO @DATA(lv_ddtext) WHERE tabname = @lv_tab AND ddlanguage = @sy-langu.
DATA(lv_lbl) = SWITCH string( ls_hdr-tabclass WHEN 'INTTAB' THEN 'STRUCTURE' WHEN 'TRANSP' THEN 'TRANSPARENT TABLE' WHEN 'CLUSTER' THEN 'CLUSTER TABLE' WHEN 'POOL' THEN 'POOLED TABLE' ELSE 'TABLE' ).
h1( EXPORTING iv_type = lv_lbl iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Description' iv_value = |{ lv_ddtext }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Table Class' iv_value = |{ ls_hdr-tabclass }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Storage Type' iv_value = |{ COND #( WHEN ls_hdr-columnstore = 'X' THEN 'COLUMN STORE' ELSE 'ROW STORE' ) }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Delivery Class' iv_value = |{ ls_hdr-contflag }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Auth Class' iv_value = |{ ls_hdr-authclass}| CHANGING ct_out = lt_out ).
" Get fully-expanded field list (resolves includes, aggregates etc.)
CALL FUNCTION 'DD_INT_TABL_GET' EXPORTING tabname = lv_tab langu = sy-langu IMPORTING dd02v_n = ls_d02v TABLES dd03p_n = lt_flds EXCEPTIONS internal_error = 1 OTHERS = 2.
IF sy-subrc = 0 AND ls_d02v IS NOT INITIAL.
CALL FUNCTION 'DD_TABL_EXPAND' EXPORTING dd02v_wa = ls_d02v mode = 46 prid = 0 TABLES dd03p_tab = lt_flds EXCEPTIONS illegal_parameter = 1 OTHERS = 2.
ENDIF.
blank( CHANGING ct_out = lt_out ).
APPEND '* FIELDS:' TO lt_out.
sep( CHANGING ct_out = lt_out ).
APPEND |* { 'FIELD' WIDTH = 25 ALIGN = LEFT PAD = ' ' } { 'TYPE' WIDTH = 8 ALIGN = LEFT PAD = ' ' }{ 'LEN' WIDTH = 6 ALIGN = LEFT PAD = ' ' }DEC KEY DESCRIPTION| TO lt_out.
sep( CHANGING ct_out = lt_out ).
LOOP AT lt_flds INTO DATA(ls_f) WHERE adminfield = 0 AND fieldname(1) <> '.'.
DATA(lv_key) = SWITCH string( ls_f-keyflag WHEN 'X' THEN ' X ' ELSE ' ' ).
APPEND |* { ls_f-fieldname WIDTH = 25 ALIGN = LEFT PAD = ' ' } { ls_f-datatype WIDTH = 8 ALIGN = LEFT PAD = ' ' }{ ls_f-leng WIDTH = 6 ALIGN = LEFT PAD = ' ' }{ ls_f-decimals WIDTH = 3 ALIGN = LEFT PAD = ' ' }{ lv_key }{ ls_f-ddtext }| TO lt_out.
ENDLOOP.
sep( CHANGING ct_out = lt_out ).
lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.tabl.txt' it_lines = lt_out ).
ENDMETHOD.
"--------------------------------------------------------------------------
" DTEL - direct SELECT from DD04V view + DD04T text
"--------------------------------------------------------------------------
METHOD write_dtel.
DATA lt_out TYPE ty_str_lines.
DATA ls_v TYPE dd04v.
DATA ls_t TYPE dd04t.
DATA lv_roll TYPE rollname.
lv_roll = iv_name.
SELECT SINGLE domname, datatype, leng, decimals, shlpname FROM dd04v INTO @DATA(ls_v_sel) WHERE rollname = @lv_roll AND as4local = 'A'.
SELECT SINGLE ddtext, scrtext_s, scrtext_m, scrtext_l, reptext FROM dd04t INTO @DATA(ls_t_sel) WHERE rollname = @lv_roll AND ddlanguage = @sy-langu.
h1( EXPORTING iv_type = 'DATA ELEMENT' iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Description' iv_value = |{ ls_t_sel-ddtext }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Domain' iv_value = |{ ls_v_sel-domname }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Data Type' iv_value = |{ ls_v_sel-datatype }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Length' iv_value = |{ ls_v_sel-leng }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Decimals' iv_value = |{ ls_v_sel-decimals }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Search Help' iv_value = |{ ls_v_sel-shlpname }| CHANGING ct_out = lt_out ).
blank( CHANGING ct_out = lt_out ).
APPEND '* FIELD LABELS:' TO lt_out.
attr( EXPORTING iv_label = 'Short' iv_value = |{ ls_t_sel-scrtext_s }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Medium' iv_value = |{ ls_t_sel-scrtext_m }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Long' iv_value = |{ ls_t_sel-scrtext_l }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Heading' iv_value = |{ ls_t_sel-reptext }| CHANGING ct_out = lt_out ).
lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.dtel.txt' it_lines = lt_out ).
ENDMETHOD.
"--------------------------------------------------------------------------
" DOMA - header via DD01V + fixed values via DD_DOMA_GET (reference prog)
"--------------------------------------------------------------------------
METHOD write_doma.
DATA lt_out TYPE ty_str_lines.
DATA lt_fvals TYPE STANDARD TABLE OF dd07v WITH DEFAULT KEY.
DATA lv_dom TYPE domname.
lv_dom = iv_name.
SELECT SINGLE datatype, leng, decimals, outputlen, lowercase, convexit, entitytab FROM dd01v INTO @DATA(ls_v) WHERE domname = @lv_dom AND as4local = 'A'.
SELECT SINGLE ddtext FROM dd01t INTO @DATA(lv_ddtext) WHERE domname = @lv_dom AND ddlanguage = @sy-langu.
" DD_DOMA_GET returns fixed values with texts in one call
CALL FUNCTION 'DD_DOMA_GET' EXPORTING domain_name = lv_dom get_state = 'A ' langu = sy-langu withtext = 'X' TABLES dd07v_tab_a = lt_fvals EXCEPTIONS illegal_value = 1 op_failure = 2 OTHERS = 3.
h1( EXPORTING iv_type = 'DOMAIN' iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Description' iv_value = |{ lv_ddtext }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Data Type' iv_value = |{ ls_v-datatype }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Length' iv_value = |{ ls_v-leng }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Decimals' iv_value = |{ ls_v-decimals }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Output Length' iv_value = |{ ls_v-outputlen }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Lowercase' iv_value = |{ ls_v-lowercase }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Conversion Exit' iv_value = |{ ls_v-convexit }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Value Table' iv_value = |{ ls_v-entitytab }| CHANGING ct_out = lt_out ).
IF lt_fvals IS NOT INITIAL.
blank( CHANGING ct_out = lt_out ).
APPEND '* FIXED VALUES:' TO lt_out.
sep( CHANGING ct_out = lt_out ).
APPEND |* { 'LOW' WIDTH = 20 ALIGN = LEFT PAD = ' ' } { 'HIGH' WIDTH = 20 ALIGN = LEFT PAD = ' ' } DESCRIPTION| TO lt_out.
sep( CHANGING ct_out = lt_out ).
LOOP AT lt_fvals INTO DATA(ls_v2).
APPEND |* { ls_v2-domvalue_l WIDTH = 20 ALIGN = LEFT PAD = ' ' } { ls_v2-domvalue_h WIDTH = 20 ALIGN = LEFT PAD = ' ' } { ls_v2-ddtext }| TO lt_out.
ENDLOOP.
sep( CHANGING ct_out = lt_out ).
ENDIF.
lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.doma.txt' it_lines = lt_out ).
ENDMETHOD.
"--------------------------------------------------------------------------
" VIEW - DD25V header + DD26E base tables + DD27P field mapping
"--------------------------------------------------------------------------
METHOD write_view.
DATA lt_out TYPE ty_str_lines.
DATA lt_tabs TYPE STANDARD TABLE OF dd26e WITH DEFAULT KEY.
DATA lt_flds TYPE STANDARD TABLE OF dd27p WITH DEFAULT KEY.
DATA lv_view TYPE viewname.
lv_view = iv_name.
SELECT SINGLE viewclass FROM dd25v INTO @DATA(lv_vclass) WHERE viewname = @lv_view AND as4local = 'A'.
SELECT SINGLE ddtext FROM dd25t INTO @DATA(lv_ddtext) WHERE viewname = @lv_view AND ddlanguage = @sy-langu.
SELECT tabname FROM dd26e INTO TABLE @lt_tabs WHERE viewname = @lv_view.
SELECT viewfield, tabname, fieldname FROM dd27p INTO TABLE @lt_flds WHERE viewname = @lv_view ORDER BY viewfield.
h1( EXPORTING iv_type = 'VIEW' iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Description' iv_value = |{ lv_ddtext }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'View Class' iv_value = |{ lv_vclass }| CHANGING ct_out = lt_out ).
IF lt_tabs IS NOT INITIAL.
blank( CHANGING ct_out = lt_out ).
APPEND '* BASE TABLES:' TO lt_out.
LOOP AT lt_tabs INTO DATA(ls_t).
APPEND |* -> { ls_t-tabname }| TO lt_out.
ENDLOOP.
ENDIF.
IF lt_flds IS NOT INITIAL.
blank( CHANGING ct_out = lt_out ).
APPEND '* FIELD MAPPING:' TO lt_out.
sep( CHANGING ct_out = lt_out ).
APPEND |* { 'VIEW FIELD' WIDTH = 22 ALIGN = LEFT PAD = ' ' } { 'TABLE' WIDTH = 14 ALIGN = LEFT PAD = ' ' } TABLE FIELD| TO lt_out.
sep( CHANGING ct_out = lt_out ).
LOOP AT lt_flds INTO DATA(ls_f).
APPEND |* { ls_f-viewfield WIDTH = 22 ALIGN = LEFT PAD = ' ' } { ls_f-tabname WIDTH = 14 ALIGN = LEFT PAD = ' ' } { ls_f-fieldname }| TO lt_out.
ENDLOOP.
sep( CHANGING ct_out = lt_out ).
ENDIF.
lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.view.txt' it_lines = lt_out ).
ENDMETHOD.
"--------------------------------------------------------------------------
" SHLP - DD30V header + DD32V parameters
" Fields used: shlpname (parameter name in DD32V), fieldname, lpos, spos
" shlpparm does NOT exist in all releases; avoided deliberately
"--------------------------------------------------------------------------
METHOD write_shlp.
DATA lt_out TYPE ty_str_lines.
DATA lt_pars TYPE STANDARD TABLE OF dd32v WITH DEFAULT KEY.
DATA lv_shlp TYPE shlpname.
lv_shlp = iv_name.
SELECT SINGLE selmtype FROM dd30v INTO @DATA(lv_selmtype) WHERE shlpname = @lv_shlp AND as4local = 'A'.
SELECT SINGLE ddtext FROM dd30t INTO @DATA(lv_ddtext) WHERE shlpname = @lv_shlp AND ddlanguage = @sy-langu.
SELECT shlpname, fieldname, lpos, spos FROM dd32v INTO TABLE @lt_pars WHERE shlpname = @lv_shlp.
h1( EXPORTING iv_type = 'SEARCH HELP' iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Description' iv_value = |{ lv_ddtext }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Selection Method' iv_value = |{ lv_selmtype }| CHANGING ct_out = lt_out ).
IF lt_pars IS NOT INITIAL.
blank( CHANGING ct_out = lt_out ).
APPEND '* PARAMETERS:' TO lt_out.
sep( CHANGING ct_out = lt_out ).
APPEND |* { 'PARAMETER' WIDTH = 20 ALIGN = LEFT PAD = ' ' } { 'FIELD' WIDTH = 20 ALIGN = LEFT PAD = ' ' } LPOS SPOS| TO lt_out.
sep( CHANGING ct_out = lt_out ).
LOOP AT lt_pars INTO DATA(ls_p).
APPEND |* { ls_p-shlpname WIDTH = 20 ALIGN = LEFT PAD = ' ' } { ls_p-fieldname WIDTH = 20 ALIGN = LEFT PAD = ' ' } { ls_p-lpos WIDTH = 4 ALIGN = LEFT PAD = ' ' } { ls_p-spos }| TO lt_out.
ENDLOOP.
sep( CHANGING ct_out = lt_out ).
ENDIF.
lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.shlp.txt' it_lines = lt_out ).
ENDMETHOD.
"--------------------------------------------------------------------------
" MSAG - T100A header + T100 messages (all languages)
"--------------------------------------------------------------------------
METHOD write_msag.
DATA lt_out TYPE ty_str_lines.
DATA lv_msg TYPE arbgb.
lv_msg = iv_name.
SELECT SINGLE stext FROM t100a INTO @DATA(lv_stext) WHERE arbgb = @lv_msg.
h1( EXPORTING iv_type = 'MESSAGE CLASS' iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Description' iv_value = |{ lv_stext }| CHANGING ct_out = lt_out ).
blank( CHANGING ct_out = lt_out ).
sep( CHANGING ct_out = lt_out ).
APPEND |* { 'NO' WIDTH = 5 ALIGN = LEFT PAD = ' ' } { 'LANG' WIDTH = 5 ALIGN = LEFT PAD = ' ' } TEXT| TO lt_out.
sep( CHANGING ct_out = lt_out ).
SELECT msgnr, sprsl, text FROM t100 INTO TABLE @DATA(lt_msgs) WHERE arbgb = @lv_msg ORDER BY msgnr, sprsl.
LOOP AT lt_msgs INTO DATA(ls_m).
APPEND |* { ls_m-msgnr WIDTH = 5 ALIGN = LEFT PAD = ' ' } { ls_m-sprsl WIDTH = 5 ALIGN = LEFT PAD = ' ' } { ls_m-text }| TO lt_out.
ENDLOOP.
sep( CHANGING ct_out = lt_out ).
lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.msag.txt' it_lines = lt_out ).
ENDMETHOD.
"--------------------------------------------------------------------------
" ENHS - Enhancement spot + embedded BAdI definitions + hook spots
"--------------------------------------------------------------------------
METHOD write_enhs.
DATA lt_out TYPE ty_str_lines.
h1( EXPORTING iv_type = 'ENHANCEMENT SPOT' iv_name = |{ iv_name }| CHANGING ct_out = lt_out ).
TRY.
DATA(lo_spot) = cl_enh_factory=>get_enhancement_spot( spot_name = CONV enhspotname( iv_name ) ).
DATA(lt_badi) = lo_spot->get_badi_definitions( ).
IF lt_badi IS NOT INITIAL.
blank( CHANGING ct_out = lt_out ).
APPEND '* BADI DEFINITIONS:' TO lt_out.
LOOP AT lt_badi INTO DATA(ls_b).
sep( CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'BAdI Name' iv_value = |{ ls_b-badi_name }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Description' iv_value = |{ ls_b-short_text }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Interface' iv_value = |{ ls_b-interface_name }| CHANGING ct_out = lt_out ).
attr( EXPORTING iv_label = 'Multi-use' iv_value = |{ ls_b-multiple_use }| CHANGING ct_out = lt_out ).
ENDLOOP.
sep( CHANGING ct_out = lt_out ).
ENDIF.
DATA(lt_hooks) = lo_spot->get_hook_spots( ).
IF lt_hooks IS NOT INITIAL.
blank( CHANGING ct_out = lt_out ).
APPEND '* HOOK SPOTS:' TO lt_out.
sep( CHANGING ct_out = lt_out ).
LOOP AT lt_hooks INTO DATA(ls_h).
APPEND |* { ls_h-hook_name }| TO lt_out.
ENDLOOP.
sep( CHANGING ct_out = lt_out ).
ENDIF.
CATCH cx_enh_root INTO DATA(lx).
APPEND |* Could not read spot details: { lx->get_text( ) }| TO lt_out.
ENDTRY.
lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.enhs.txt' it_lines = lt_out ).
ENDMETHOD.
"--------------------------------------------------------------------------
" DDLS / DDLX / DCLS - Core Data Services Source (S/4HANA centric)
"--------------------------------------------------------------------------
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
lcl_file_writer=>write_lines( iv_path = iv_dir && iv_name && '.dcls.as dcls' it_lines = lt_out ).
ENDIF.
ENDMETHOD.
ENDCLASS.
*----------------------------------------------------------------------*
* CLASS: LCL_PACKAGE_COLLECTOR
* Walks TDEVC recursively to discover all subpackages,
* then bulk-fetches TADIR objects in one FOR ALL ENTRIES SELECT.
*----------------------------------------------------------------------*
CLASS lcl_package_collector DEFINITION FINAL.
PUBLIC SECTION.
TYPES tt_devclass TYPE STANDARD TABLE OF devclass WITH DEFAULT KEY.
METHODS constructor IMPORTING iv_root TYPE devclass.
METHODS collect RAISING lcx_export_error.
METHODS get_objects_for IMPORTING iv_pack TYPE devclass RETURNING VALUE(rt_objs) TYPE tt_tadir_obj.
METHODS get_children_of IMPORTING iv_pack TYPE devclass RETURNING VALUE(rt_packs) TYPE tt_devclass.
METHODS get_total_count RETURNING VALUE(rv_n) TYPE i.
PRIVATE SECTION.
DATA mv_root TYPE devclass.
DATA mt_packs TYPE tt_devclass.
DATA mt_objects TYPE tt_tadir_obj.
METHODS recurse IMPORTING iv_pack TYPE devclass.
ENDCLASS.
CLASS lcl_package_collector IMPLEMENTATION.
METHOD constructor.
mv_root = iv_root.
ENDMETHOD.
METHOD collect.
" Validate root package exists
SELECT SINGLE devclass FROM tdevc INTO @DATA(lv_chk) WHERE devclass = @mv_root.
IF sy-subrc <> 0.
RAISE EXCEPTION TYPE lcx_export_error EXPORTING iv_msg = |Package '{ mv_root }' not found in TDEVC|.
ENDIF.
APPEND mv_root TO mt_packs.
recurse( mv_root ).
" One SELECT for all objects across all collected packages
SELECT pgmid, object, obj_name, devclass FROM tadir INTO TABLE @mt_objects FOR ALL ENTRIES IN @mt_packs WHERE devclass = @mt_packs-table_line AND pgmid = 'R3TR' AND delflag = space.
SORT mt_objects BY devclass object obj_name.
ENDMETHOD.
METHOD recurse.
SELECT devclass FROM tdevc INTO TABLE @DATA(lt_children) WHERE parentcl = @iv_pack.
LOOP AT lt_children INTO DATA(lv_child).
IF NOT line_exists( mt_packs[ table_line = lv_child ] ).
APPEND lv_child TO mt_packs.
recurse( lv_child ).
ENDIF.
ENDLOOP.
ENDMETHOD.
METHOD get_objects_for.
rt_objs = FILTER #( mt_objects USING KEY primary_key WHERE devclass = iv_pack ).
ENDMETHOD.
METHOD get_children_of.
SELECT devclass FROM tdevc INTO TABLE @rt_packs WHERE parentcl = @iv_pack.
ENDMETHOD.
METHOD get_total_count.
rv_n = lines( mt_objects ).
ENDMETHOD.
ENDCLASS.
*----------------------------------------------------------------------*
* CLASS: LCL_EXPORTER (Orchestrator)
*----------------------------------------------------------------------*
CLASS lcl_exporter DEFINITION FINAL.
PUBLIC SECTION.
METHODS constructor IMPORTING iv_pack TYPE devclass iv_path TYPE string.
METHODS run RAISING lcx_export_error.
PRIVATE SECTION.
DATA mv_pack TYPE devclass.
DATA mv_base TYPE string. " normalised base path (trailing \)
DATA mo_coll TYPE REF TO lcl_package_collector.
DATA mv_done TYPE i.
DATA mv_total TYPE i.
METHODS process_package IMPORTING iv_pack TYPE devclass iv_folder TYPE string. " full path to this package's folder
METHODS process_object IMPORTING is_obj TYPE ty_tadir_obj iv_src TYPE string. " full path to src\ folder
METHODS write_devc IMPORTING iv_pack TYPE devclass iv_folder TYPE string.
METHODS tick IMPORTING iv_text TYPE string.
ENDCLASS.
CLASS lcl_exporter IMPLEMENTATION.
METHOD constructor.
mv_pack = iv_pack.
" Normalise: ensure trailing backslash
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
WRITE: / |Collecting package tree for { mv_pack }...|.
mo_coll->collect( ).
mv_total = mo_coll->get_total_count( ).
WRITE: / |Found { mv_total } objects. Writing to { mv_base }{ mv_pack }\|.
process_package( iv_pack = mv_pack iv_folder = mv_base && mv_pack && '\' ).
SKIP.
WRITE: / |=== Export complete: { mv_done } of { mv_total } objects written ===|.
WRITE: / |Folder : { mv_base }{ mv_pack }\|.
WRITE: / |Ready : cd to folder and run git init then git remote add origin <url> then git push|.
ENDMETHOD.
METHOD write_devc.
DATA lt_out TYPE ty_str_lines.
SELECT SINGLE ctext, parentcl FROM tdevc INTO @DATA(ls_pkg) WHERE devclass = @iv_pack.
APPEND |* ================================================================| TO lt_out.
APPEND |* PACKAGE: { iv_pack }| TO lt_out.
APPEND |* ================================================================| TO lt_out.
APPEND |* Description : { ls_pkg-ctext }| TO lt_out.
APPEND |* Parent Package : { ls_pkg-parentcl }| TO lt_out.
APPEND |* Exported : { sy-datum DATE = ENVIRONMENT } { sy-uzeit TIME = ENVIRONMENT }| TO lt_out.
APPEND |* System : { sy-sysid } / Client { sy-mandt }| TO lt_out.
lcl_file_writer=>write_lines( iv_path = iv_folder && iv_pack && '.devc.txt' it_lines = lt_out ).
ENDMETHOD.
METHOD process_package.
write_devc( iv_pack = iv_pack iv_folder = iv_folder ).
DATA(lv_src) = iv_folder && 'src\'.
LOOP AT mo_coll->get_objects_for( iv_pack ) INTO DATA(ls_obj).
tick( |{ ls_obj-object } { ls_obj-obj_name }| ).
TRY.
process_object( is_obj = ls_obj iv_src = lv_src ).
CATCH cx_root INTO DATA(lx).
WRITE: / | WARNING { ls_obj-object } { ls_obj-obj_name }: { lx->get_text( ) }|.
ENDTRY.
ENDLOOP.
" Recurse into direct child packages
LOOP AT mo_coll->get_children_of( iv_pack ) INTO DATA(lv_child).
process_package( iv_pack = lv_child iv_folder = iv_folder && lv_child && '\' ).
ENDLOOP.
ENDMETHOD.
METHOD process_object.
CASE is_obj-object.
" -- Source-based objects --------------------------------------
WHEN 'CLAS'.
lcl_source_reader=>write_class( iv_name = is_obj-obj_name iv_dir = iv_src ).
WHEN 'PROG'.
lcl_source_reader=>write_prog( iv_name = is_obj-obj_name iv_dir = iv_src ).
WHEN 'INTF'.
lcl_source_reader=>write_intf( iv_name = is_obj-obj_name iv_dir = iv_src ).
WHEN 'FUGR'.
lcl_source_reader=>write_fugr( iv_name = is_obj-obj_name iv_dir = iv_src ).
WHEN 'TYPE'.
lcl_source_reader=>write_type( iv_name = is_obj-obj_name iv_dir = iv_src ).
" -- DDIC objects ----------------------------------------------
WHEN 'TABL'.
lcl_ddic_reader=>write_tabl( iv_name = is_obj-obj_name iv_dir = iv_src ).
WHEN 'DTEL'.
lcl_ddic_reader=>write_dtel( iv_name = is_obj-obj_name iv_dir = iv_src ).
WHEN 'DOMA'.
lcl_ddic_reader=>write_doma( iv_name = is_obj-obj_name iv_dir = iv_src ).
WHEN 'VIEW'.
lcl_ddic_reader=>write_view( iv_name = is_obj-obj_name iv_dir = iv_src ).
WHEN 'SHLP'.
lcl_ddic_reader=>write_shlp( iv_name = is_obj-obj_name iv_dir = iv_src ).
WHEN 'MSAG'.
lcl_ddic_reader=>write_msag( iv_name = is_obj-obj_name iv_dir = iv_src ).
WHEN 'ENHS'.
lcl_ddic_reader=>write_enhs( iv_name = is_obj-obj_name iv_dir = iv_src ).
WHEN 'DDLS'.
lcl_ddic_reader=>write_ddls( iv_name = is_obj-obj_name iv_dir = iv_src ).
WHEN 'DDLX'.
lcl_ddic_reader=>write_ddlx( iv_name = is_obj-obj_name iv_dir = iv_src ).
WHEN 'DCLS'.
lcl_ddic_reader=>write_dcls( iv_name = is_obj-obj_name iv_dir = iv_src ).
" -- Unsupported: write a stub so the object is not silently lost
WHEN OTHERS.
DATA lt_stub TYPE ty_str_lines.
APPEND |* Object type { is_obj-object } not handled by this exporter.| TO lt_stub.
APPEND |* Object name : { is_obj-obj_name }| TO lt_stub.
APPEND |* Add a handler in LCL_SOURCE_READER or LCL_DDIC_READER.| TO lt_stub.
lcl_file_writer=>write_lines( iv_path = iv_src && is_obj-obj_name && '.' && is_obj-object && '.txt' it_stub = lt_stub ).
ENDCASE.
ENDMETHOD.
ENDCLASS.
*----------------------------------------------------------------------*
* SELECTION SCREEN EVENTS
*----------------------------------------------------------------------*
AT SELECTION-SCREEN ON p_pack.
SELECT SINGLE devclass FROM tdevc INTO @DATA(lv_exists) WHERE devclass = @p_pack.
IF sy-subrc <> 0.
MESSAGE |Package '{ p_pack }' does not exist in this system.| TYPE 'E'.
ENDIF.
AT SELECTION-SCREEN ON p_path.
IF p_path IS INITIAL.
MESSAGE 'Please enter a local destination path.' TYPE 'E'.
ENDIF.
*----------------------------------------------------------------------*
* START-OF-SELECTION
*----------------------------------------------------------------------*
START-OF-SELECTION.
TRY.
NEW lcl_exporter( iv_pack = p_pack iv_path = p_path )->run( ).
CATCH lcx_export_error INTO DATA(lx).
MESSAGE lx->get_text( ) TYPE 'E'.
ENDTRY.