# GAP Maps

This project maps and summarizes GAP protection status for CA-SSN sites using PAD-US 4.1.

## What This Project Does

- Assigns each CA-SSN site a GAP status (1–4, or `NA` when no overlap is found).
- Produces tabular outputs for analysis.
- Produces map outputs for all sites and by organization.

> **Note:** Sites with `NA` status are labeled **"No Data"** — this means the site did not spatially overlap any PAD-US polygon. It does **not** mean the site is unprotected. 19 sites (mostly CSU/UCNRS on private land) fall in this category.

## Data Sources

### 1) CASSN reference sites (input points)

- Source file used by the extraction script: `projects/_reference/data_raw/CASSN_all_sites.csv`
- Contains sentinel site metadata including `site_name`, `organization`, `latitude`, and `longitude`.

### 2) PAD-US 4.1 polygons (protection status)

- Source: USGS PAD-US 4.1 California data
- Primary project input (tracked with Git LFS):
  - `data/padus_ca_subset.gpkg`
  - layer: `padus_ca_subset`
- Fallback input (if subset is missing):
  - external `.gdb` path configured in `scripts/01_extract_gap_status.R`
- Key fields used:
  - `GAP_Sts` (status code)
  - `d_GAP_Sts` (status description)

## PAD-US Storage Strategy

The repository uses Git LFS for the PAD-US project subset file:

- tracked file: `data/padus_ca_subset.gpkg`
- tracking rule: `.gitattributes`

## Data Outputs

Generated under `data/`:

- `cassn_gap_status.csv`: site-level table with GAP status.
- `cassn_gap_status.gpkg`: spatial version of the same site-level output.
- `gap_status_lookup.csv`: lookup table of GAP status definitions.

Generated under `outputs/maps/`:

- `gap_all_sites.png`
- `gap_owner_CDFW.png`
- `gap_owner_CSU.png`
- `gap_owner_Pepperwood.png`
- `gap_owner_TNC.png`
- `gap_owner_UCNRS.png`

## Color Palette

| GAP Status | Label | Color |
|------------|-------|-------|
| 1 | Managed for biodiversity — disturbance events proceed or are mimicked | `#0B6E4F` (dark green) |
| 2 | Managed for biodiversity — disturbance events suppressed | `#F2C300` (yellow) |
| 3 | Managed for multiple uses — generally extractive | `#F28E1C` (orange) |
| 4 | No known mandate for biodiversity protection | `#C81D25` (red) |
| No Data | No PAD-US polygon overlap found | `#AAAAAA` (gray) |

## Scripts

- `scripts/00_setup.R`
  - Installs and loads required R packages (project-local `.Rlib` when needed).

- `scripts/01_extract_gap_status.R`
  - Main processing script.
  - Reads reference sites and PAD-US polygons.
  - Performs spatial join and picks best (lowest) GAP status per site.
  - Writes `data/cassn_gap_status.csv`, `data/cassn_gap_status.gpkg`, and `data/gap_status_lookup.csv`.

- `scripts/02_explore.qmd`
  - Exploratory report for summaries, tables, distributions, and a quick interactive map.

- `scripts/03_maps.qmd`
  - Interactive leaflet map outputs/tables by organization and across all sites.

- `scripts/04_static_maps.qmd`
  - Static publication-style map generation.
  - Produces PNGs in `outputs/maps/` with:
    - legend blocks,
    - site counts table,
    - GAP status definition table.

## Typical Run Order

1. Run `scripts/00_setup.R`
2. Run `scripts/01_extract_gap_status.R`
3. Render reports/maps as needed:
   - `quarto render scripts/02_explore.qmd`
   - `quarto render scripts/03_maps.qmd`
   - `quarto render scripts/04_static_maps.qmd`
