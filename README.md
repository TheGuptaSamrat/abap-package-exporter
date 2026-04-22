# ABAP Package Exporter

ABAP utility report for exporting repository objects from an SAP package into a ZIP file with a structure that is easier to inspect outside the SAP system.

## What it exports

- Programs (`PROG`) with main program and includes
- Classes (`CLAS`) with separate class-pool parts where available
- Function groups (`FUGR`) with main program, includes, and function module inventory
- DDIC tables (`TABL`) with field and technical metadata
- DDIC views (`VIEW`) with table and field metadata

## SAP compatibility

- Targeted for `SAP_BASIS 7.51`
- Uses conservative ABAP syntax
- Avoids modern syntax that is risky on older systems

## Repository layout

```text
src/
  Z_EXPORT_PKG_ADT_TEXT.abap
docs/
  REVIEW_NOTES.md
```

## ZIP output layout

```text
src/prog/<program>/main.abap
src/prog/<program>/includes/<include>.abap
src/clas/<class>/cp.abap
src/clas/<class>/ccdef.abap
src/clas/<class>/ccimp.abap
src/clas/<class>/ccmac.abap
src/clas/<class>/ccau.abap
src/fugr/<group>/main.abap
src/fugr/<group>/includes/<include>.abap
src/fugr/<group>/function_modules.txt
src/ddic/tabl/<table>.txt
src/ddic/view/<view>.txt
logs/export_log.txt
logs/export_summary.txt
```

## Usage

1. Create the report in SAP as `Z_EXPORT_PKG_ADT_TEXT`.
2. Copy the contents of [`src/Z_EXPORT_PKG_ADT_TEXT.abap`](./src/Z_EXPORT_PKG_ADT_TEXT.abap).
3. Execute the report with:
   - `P_PACK` = package name
   - `P_PATH` = local ZIP target path

## Notes

- `GUI_DOWNLOAD` means the report is intended for dialog execution, not background mode.
- Unsupported package object types are logged so gaps are visible during export.
- CDS views, interfaces, and enhancements are intentionally not force-exported by unreliable assumptions in this version.
