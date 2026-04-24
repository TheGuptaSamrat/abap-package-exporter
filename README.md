# ABAP Package Exporter (Direct Folder Download)

ABAP utility report for exporting repository objects from an SAP package directly into a local folder structure. This version is optimized for Git readiness, bypassing ZIP accumulation to handle very large packages without memory issues.

It is designed as a conservative, SAP_BASIS 7.51-compatible report for teams that want a readable text export without depending on newer ADT-only APIs or abapGit internals.

## Key Features

- **Direct Folder Download**: Writes files directly to a local path (e.g. `C:\SAP_Export\`) via `GUI_DOWNLOAD`.
- **Git-Ready Layout**: Mirrors the ADT Package Explorer structure, allowing for immediate `git init` and `git push`.
- **Memory Efficient**: Objects are processed and written individually, avoiding `xstring` accumulation or ZIP size limits.
- **Broad Object Support**: Handles Programs, Classes, Interfaces, Function Groups, and full DDIC metadata (Tables, Views, Domains, Data Elements, etc.).
- **CDS Support**: Full support for Core Data Services (DDLS, DDLX, DCLS) on HANA systems.

## What it exports

- Programs (`PROG`) with main program and includes
- Classes (`CLAS`) with separate class-pool parts (Locals, Macros, Tests)
- Function groups (`FUGR`) with main program, includes, and function module inventory
- DDIC tables (`TABL`) with expanded field and technical metadata
- DDIC views (`VIEW`) with table and field mapping
- Data elements (`DTEL`) and Domains (`DOMA`) with fixed values
- Message classes (`MSAG`) with message texts
- Enhancement spots (`ENHS`) and BAdI definitions
- Core Data Services (`DDLS`, `DDLX`, `DCLS`) as `.asddls` / `.asddlxs` / `.asdcls`

## Repository Layout

```text
src/
  Z_EXPORT_PACKAGE_SOURCE.abap (The report)
    ...
      <PROG>.prog.abap
        <INTF>.intf.abap
          <CLAS>/
              <CLAS>.clas.abap
                  <CLAS>.clas.locals_def.abap
                      ...
                        <FUGR>/
                            <FUGR>.fugr.abap
                                <FM>.fugr.func.abap
                                  <TABL>.tabl.txt
                                    <DDLS>.ddls.asddls
                                    ```

                                    ## Usage

                                    1. Create the report in SAP using the source in `src/Z_EXPORT_PACKAGE_SOURCE.abap`.
                                    2. Execute the report.
                                    3. Enter the Package name and the Local Target Path (e.g. `C:\SAP_Export\`).
                                    4. Execute (F8).

                                    ## SAP Compatibility

                                    - Targeted for `SAP_BASIS 7.51` and higher.
                                    - Works on HANA and non-HANA systems (CDS objects skipped if tables missing).
                                    - Uses conservative ABAP syntax to ensure maximum compatibility.
                                    - Uses `GUI_DOWNLOAD` with `FILETYPE='ASC'` for direct filesystem output.

                                    ## License

                                    MIT
                                    