# dazu-pbi-workspace

Parent-Projekt für `dazu-pbi` und `sap-bo`.

## Setup

```bash
git clone git@github.com:stallen-arch/dazu-pbi-workspace.git pbi-git
cd pbi-git
./init.sh
```

Voraussetzungen: Git (unter Windows Git Bash), Python >= 3.9, SSH-Zugang zu GitHub.

`init.sh` richtet die (hier git-ignorierten) Sub-Repos ein und installiert die Python-Pakete aus
`requirements.txt` (für `sap-bo/*/generate_*.py`, `sap-bo/validate_pbir.py`); mehrfaches Ausführen ist unkritisch.

| Ordner          | Quelle                              | Branch |
|-----------------|-------------------------------------|--------|
| `dazu-pbi-test` | Clone `stallen-arch/dazu-pbi`       | test   |
| `dazu-pbi-int`  | Worktree von `dazu-pbi-test`        | int    |
| `dazu-pbi-prod` | Worktree von `dazu-pbi-test`        | prod   |
| `sap-bo`        | Clone `stallen-arch/sap-bo`         | main   |

Optional andere URLs (z. B. HTTPS): `DAZU_PBI_URL=... SAP_BO_URL=... ./init.sh`

## Skripte

- `init.sh` – Sub-Repos clonen / Worktrees anlegen
- `pull-all.sh` – alle Stages aktualisieren (`--ff-only`, überspringt Ordner mit lokalen Änderungen)
- `push-all.sh` – lokale Änderungen committen und alle Stages pushen
