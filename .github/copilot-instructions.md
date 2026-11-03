# Copilot Instructions — dazu-pbi (SAP BO → Power BI Migration)

## Project overview
This repo (`stallen-arch/dazu-pbi`) backs an ongoing migration of ~51 SAP BusinessObjects
reports (built on ~6 universes/semantic models) to Power BI / Microsoft Fabric. Content is
authored in Fabric workspaces and synced here via Fabric Git integration in PBIP/TMDL text
format (semantic models, reports, paginated reports, dataflows).

## Repo / branch layout
- Single Git repo with three long-lived branches, each connected to its own Fabric workspace:
  - `int` → folder `dazu-pbi-int/` — Fabric "int" workspace
  - `test` → folder `dazu-pbi-test/` — Fabric "test" workspace
  - `prod` → folder `dazu-pbi-prod/` — Fabric "prod" workspace
- Each branch/folder contains PBIP items: `*.SemanticModel`, `*.Report`,
  `*.PaginatedReport`, `*.Dataflow`. Semantic models use TMDL (`definition/*.tmdl`).
- Promotion flow is int → test → prod. Item names (display names) should match exactly
  across branches once promoted — Fabric deployment pipelines and manual comparisons match
  items by name, so naming drift between branches breaks promotion/parity checks.
- `dazu-pbi-test` is the primary clone (owns the real `.git` directory); `dazu-pbi-int`
  and `dazu-pbi-prod` are `git worktree` checkouts sharing its object store (their `.git`
  is a file with a `gitdir:` pointer, not a directory). This is expected — treat each
  folder as an independent working tree/branch regardless.
- Use `pull-all.sh` at the repo root to sync all three stages at once (`git fetch` +
  `git pull --ff-only` per folder). It skips any stage with uncommitted changes or a
  wrong checked-out branch rather than risking data loss.

## Data source convention (intentional, do not "fix")
- **int** and **prod** workspaces both connect to the **production Oracle DB**
  (e.g. `DataFlow ... Oracle PROD DB.Dataflow`). This is expected: int validates against
  real prod data before promoting to prod.
- **test** workspace connects to the **test Oracle DB** (`DataFlow Oracle TEST DB.Dataflow`).
- When reviewing dataflows/semantic model data source settings, do not treat
  int → PROD DB as a bug — only flag it if a data source clearly points to the wrong
  environment in a way inconsistent with this rule (e.g. test pointing at PROD DB, or
  prod pointing at TEST DB).

## Known naming drift to watch for (pre-existing, being cleaned up)
- Some paginated report names differ only by underscore/hyphen placement between branches
  (e.g. `Export_NID_ENGINEtoILTIS_...` vs `Export_NID_ENGINE_to_ILTIS_...`).
- `test` currently has `OBU_ID_L2_Monitoring_splnk.Report` while `int`/`prod` have the
  same item as `.PaginatedReport` — a type mismatch, not just a naming difference.
- `test` has extra/duplicate-looking items (`BBW_Streckendomäne2.PaginatedReport`,
  `Streckendomäne_BBW_BBW.PaginatedReport`) not present in int/prod.
- When asked to align or clean up environments, confirm intent before renaming/deleting,
  since these may be work-in-progress items.

## Working conventions
- Prefer editing TMDL/PBIR source files directly over regenerating from Power BI Desktop.
- Keep display names and folder names identical across `int`/`test`/`prod` for any item
  meant to be promoted through the pipeline.
- German umlauts appear in item/table names (e.g. `Streckendomäne`) — preserve encoding
  exactly when editing.
- Track SAP BO → Power BI migration mapping (source report/universe → target semantic
  model/report → status) in a dedicated mapping doc as it's built out; don't assume parity
  with SAP BO features (contexts, derived tables, free-hand SQL, alerters) without checking.
- `dbq.sh` (in `PATH`, located at `~/bin/dbq.sh`) runs SQL against the Oracle **TEST** DB
  (saved SQLcl connection `dazu_test`, read-only user). Use it for data/DB checks
  (e.g. invalid dates, row counts, column types) instead of guessing.
  - Usage: `dbq.sh "select ... from DAZU.<TABLE> where rownum <= 10"`
  - Pass exactly one statement, **without** trailing `;` (the script appends it).
  - Output is CSV without headers/feedback (`sqlformat csv`, `pagesize 0`); add column
    names to the SELECT if headers are needed.
  - Schema is `DAZU`. Only SELECTs — never attempt DML/DDL.
  - It queries TEST, not PROD: int/prod data issues (e.g. refresh warnings) may not be
    reproducible there. Say so when results could differ.

## Repos and git (important)
- `pbi-git/` itself is NOT a git repo; `.github/` is not versioned. Repos: `dazu-pbi-int|test|prod`
  (worktrees of `stallen-arch/dazu-pbi`, branches int/test/prod) and `sap-bo/`
  (`stallen-arch/sap-bo`, branch `main`). Commit + push each separately (`git add -A . && git commit && git push`).
- Windows Python cannot read `/tmp/...` bash paths: use `cygpath -m` or relative paths; set `PYTHONIOENCODING=utf-8`.
- Deployment pipelines are NOT in git (Fabric Git syncs items only). Never claim to see them.

## SAP BO -> Power BI migration: universe AUFTRAGSMANAGEMENT2 (state 2026-10-20)
- Folder `sap-bo/DAZU_AUFTRAGSMANAGEMENT2/`: BLX/DFX exports, `reports/` (BO exports: .widx.zip, csv, pdf),
  `MIGRATION-MAPPING.md` (decisions, details; read it first), `generate_semantic_model.py` (config),
  `generate_reports.py` (3 reports), shared generator `sap-bo/idt_to_pbi.py`, `sap-bo/validate_pbir.py`
  (validates report JSON against Power BI Desktop schemas; needs `pip install jsonschema`).
- The semantic model `dazu-pbi-int/DAZU_AUFTRAGSMANAGEMENT2.SemanticModel` and dataflow
  `DataFlow AUFTRAGSMANAGEMENT2 Oracle PROD DB.Dataflow` are GENERATED. Never edit them by hand; change the
  config/generator and regenerate: `python sap-bo/DAZU_AUFTRAGSMANAGEMENT2/generate_semantic_model.py`
  (writes into the repo; reports: `python sap-bo/DAZU_AUFTRAGSMANAGEMENT2/generate_reports.py`, then validate_pbir.py).
- Model loads from the Gen2 dataflow by id `4f2896a6-b608-41a4-bd97-0b07baf60e63` (workspace `45b2a660-...`, int);
  int/prod use the PROD Oracle DB. test/prod need their own ids when promoted (not prepared).
- Reports are enhanced PBIR (`definition/` folder), bound by path to the model:
  `Auftrag_Projekt_notabgeschlossen` (user: finished, but fixed later for cross join; filter Auftrag Abgeschlossen = nein;
  Id `#,0`, dates `dd.MM.yyyy`), `Auftrag_Abgeschlossen_Projekt_not_abgeschlossen` (filters Abgeschlossen = ja and
  Deaktiviert in (0, empty), no slicer; BO prompt "Deaktiviert" is NOT used), `Auftragsliste_ZBF` (3 pages, no
  prompts/filters in BO). BO query filters/prompts are not contained in .widx: ask the user.
- Key finding: a table visual with columns of tables that are only related via a common parent becomes a CROSS JOIN
  (service error `InvalidUnconstrainedJoin`). Fix = hidden "Zeilenfilter ..." measures on AUFTRAG (generator
  `extra_measures`) shown as last narrow column "Zeile" in each table, plus helper columns on AUFTRAG_TERMIN
  (`extra_columns`, LOOKUPVALUE on composite key = BO outer join to FORTSCHRITT) and cross-filter-both relationships
  (`bidirectional_relationships`). Verified with a local engine: DAX rows = Oracle rows (55/66/2374/1656).
- `AL_PROJEKT_PROZESS` (generator `extra_tables`, calculated table, outer join AL_PROJEKT(+) per Planungsprozess)
  was pushed UNTESTED (local engine would not start): ask the user whether the model refresh works and whether
  orders 1002108.4-01/-02, 1002567.4-14/-15 show with empty Deaktiviert; revert/fix the DAX if the refresh fails.
- Open: Deaktiviert in the new report comes from AL_PROJEKT (via Planungsprozess = BO artifact); `Auftragsliste_ZBF`
  Info page is a placeholder text; footer count / BO sort by SORT not migrated; date formats only set for
  `Auftrag_Projekt_notabgeschlossen`.
- **Local test engine (use it to test model/DAX changes BEFORE pushing; needs Power BI Desktop running)**:
  - Why it "did not start": `msmdsrv.exe` exits at once (rc 0, no log, no error) when `<PrivateProcess>` is MISSING in
    the ini. Do NOT remove it; set it to the PID of a running `PBIDesktop.exe` (`tasklist | grep PBIDesktop`). The engine
    lives as long as that process. Also never point the ini at the Desktop workspace's own Data dir (locked).
  - Recipe: (1) `W=$LOCALAPPDATA/Microsoft/Power BI Desktop/AnalysisServicesWorkspaces/<existing>/Data`; copy `msmdsrv.ini`
    and `CryptKey*.bin` to e.g. `C:\Temp\asw3\Data`. (2) `sed` all `DataDir/TempDir/LogDir/BackupDir/CrashReportsFolder/
    AllowedBrowsingFolders` to that dir, `<Port>0</Port>` -> fixed port (e.g. 51999), add
    `<PrivateProcess>PID</PrivateProcess>` after `<Port>`. (3) Start via PowerShell (bash `&`/timeout also dies):
    `powershell -NoProfile -Command "Start-Process 'C:\Program Files\Microsoft Power BI Desktop\bin\msmdsrv.exe' -ArgumentList '-c','-s','C:\Temp\asw3\Data' -WindowStyle Hidden -PassThru"`;
    check `netstat -ano | grep 51999` and `Data\msmdsrv.log`. (4) Deploy the TMDL with TOM
    (`Microsoft.PowerBI.Tabular.dll`, `TmdlSerializer.DeserializeDatabaseFromFolder`), replace partitions by
    `#table(...)` with TEST data from `dbq.sh` (sample: every 10th Auftrag), query via
    `Microsoft.PowerBI.AdomdClient.dll`, compare row counts with Oracle (dbq.sh). (5) Stop with `taskkill //F //PID`
    and delete the temp dir. The test scripts are not kept in the repo; rewrite them (small PowerShell/C# or Python+pythonnet).
  - Untested DAX still pending a local run: `AL_PROJEKT_PROZESS`, `ZBF_ZWEITE_PLANUNGSSTUFE`.
## ZBF "Zweite Planungsstufe" (2026-10-21)
- BO query = AUFTRAG with OUTER joins (PRJ_ORG_PS -> PRJ_RL -> MA, Belastung on (Auftrag, PS)) and BO filter
  "SAP Auftragsnummer In Liste (Erste Planungsstufe)". Tab 2 now reads ONE flat calculated table
  `ZBF_ZWEITE_PLANUNGSSTUFE` (generator `ZBF_ZWEITE_DAX`, GENERATEALL chain) - no Zeile column. UNTESTED DAX (no local engine):
  if the model refresh fails, check/fix that DAX. Tab-1 set = Abgeschlossen = nein AND [Zeilenfilter Erste Planungsstufe].
- Tab 1 page filter Abgeschlossen = nein; formats for dates/integers set in ZBF; months `0.00;-0.00;0`.
- Sort question (SAP Auftragsnummer shown descending in PBI) still open.
## Status 2026-10-21
- Universe AUFTRAGSMANAGEMENT2 + its 3 reports (tabs of Auftragsliste_ZBF incl.) are DONE from the user's point of view. Further changes only on request.
## TGRE P44 / Report FABT_BP_V3 (2026-10-21)
- Dataflow TGRE was split (50-query limit per dataflow): `DataFlow TGRE Oracle PROD DB` (42) + `DataFlow TGRE P44 Oracle PROD DB` (13, id still `P44_DATAFLOW_ID = None` in
  `sap-bo/DAZU_TGRE_P44/generate_semantic_model.py`; ask the user for the Fabric id). Generator supports `Universe.extra_dataflows`.
- Report FABT_BP_V3 (14 tabs, one BO query per tab, prompt BP Abkuerzung = `AL_ZSPI_BETRIEBSPUNKT[BP Abkuerzung]`, MULTI select, synced slicer):
  BO SQL is saved in `sap-bo/DAZU_TGRE_P44/reports/FABT_BP_V3/queries/<Tab>.sql` (README.md there = status). Have so far: Fahrbegriffe, REPO, Paket, Korporal, SSP, Ziele, WH, MiniLEU, RS, Q_LINK, ReiheW, NC_CDDIFF=8, ReiheN (extra fixed BP filter list), FixeMA = ALL 14 tabs have SQL.
  Idea: flat base table (ZSP..DATAPACKETVARIABLE chain, outer joins) + per-tab fixed filters; avoid cross joins. widx = layout/sample rows only (no filters).
