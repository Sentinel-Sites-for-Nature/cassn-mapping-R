#!/usr/bin/env Rscript

# Extract PAD-US 4.1 GAP status for all CA-SSN sentinel sites via spatial join.
# Outputs:
#   data/cassn_gap_status.csv     — one row per site with gap_status (1–4 or NA)
#   data/gap_status_lookup.csv    — 4-row lookup table: gap_status + description

# --- PAD-US source settings ---
# Preferred: local project subset tracked via Git LFS
PADUS_SUBSET_GPKG  <- "data/padus_ca_subset.gpkg"
PADUS_SUBSET_LAYER <- "padus_ca_subset"

# Fallback: external PAD-US geodatabase (used only if subset is missing)
PADUS_GDB   <- "/Users/johnimperato/Downloads/PADUS4_1_State_CA_GDB_KMZ/PADUS4_1_StateCA.gdb"
PADUS_LAYER <- "PADUS4_1Comb_DOD_Trib_NGP_Fee_Desig_Ease_State_CA"

# ---------------------------------------------------------------------------

cwd <- getwd()
project_root <- if (basename(cwd) == "scripts") {
  normalizePath(file.path(cwd, ".."), mustWork = FALSE)
} else if (basename(cwd) %in% c("gap-maps", "2026-02_gap-maps")) {
  normalizePath(cwd, mustWork = FALSE)
} else {
  normalizePath(file.path(cwd, "projects", "gap-maps"), mustWork = FALSE)
}

project_lib <- file.path(project_root, ".Rlib")
if (dir.exists(project_lib)) .libPaths(c(project_lib, .libPaths()))

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
})

data_dir <- file.path(project_root, "data")
if (!dir.exists(data_dir)) dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

# --- 1. Load reference sites from CSV (preserves lat/lon as columns) ---
ref_csv <- normalizePath(
  file.path(project_root, "..", "_reference", "data_raw", "CASSN_all_sites.csv"),
  mustWork = FALSE
)
if (!file.exists(ref_csv)) stop("Reference CSV not found: ", ref_csv)

sites_df <- read_csv(ref_csv, show_col_types = FALSE)
sites_sf  <- st_as_sf(sites_df, coords = c("longitude", "latitude"), crs = 4326)
message("Loaded ", nrow(sites_sf), " reference sites")

# --- 2. Load PAD-US layer (polygons) ---
padus_subset_path <- file.path(project_root, PADUS_SUBSET_GPKG)
if (file.exists(padus_subset_path)) {
  message("Loading PAD-US subset from project data: ", padus_subset_path)
  padus <- st_read(padus_subset_path, layer = PADUS_SUBSET_LAYER, quiet = TRUE) %>%
    select(GAP_Sts, d_GAP_Sts)
} else {
  if (!file.exists(PADUS_GDB)) {
    stop(
      "PAD-US subset not found at ", padus_subset_path,
      " and fallback GDB not found at ", PADUS_GDB
    )
  }
  message("Loading PAD-US from external GDB (subset missing): ", PADUS_GDB)
  padus <- st_read(PADUS_GDB, layer = PADUS_LAYER, quiet = TRUE) %>%
    select(GAP_Sts, d_GAP_Sts)
}

message("Loaded ", nrow(padus), " PAD-US polygons (CRS: ", st_crs(padus)$input, ")")

# --- 3. Reproject sites to match PAD-US CRS ---
sites_proj <- st_transform(sites_sf, st_crs(padus))

# --- 4. Spatial join (one row per site × overlapping polygon) ---
message("Running spatial join...")
joined <- st_join(sites_proj, padus, join = st_within, left = TRUE)

# --- 5. Aggregate: best (lowest) GAP status per site ---
# Convert GAP_Sts to integer for min(); NA = no PAD-US coverage
best_gap <- joined %>%
  st_drop_geometry() %>%
  mutate(gap_int = suppressWarnings(as.integer(GAP_Sts))) %>%
  group_by(site_name) %>%
  slice_min(gap_int, na_rm = TRUE, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(site_name, gap_status = gap_int, gap_description = d_GAP_Sts)

# Ensure every site appears (sites_df retains lat/lon; no site_id in current schema)
result <- sites_df %>%
  left_join(best_gap, by = "site_name") %>%
  select(organization, campus, site_name, latitude, longitude, gap_status)

# --- 6. Write site CSV and GeoPackage ---
out_csv <- file.path(data_dir, "cassn_gap_status.csv")
write_csv(result, out_csv)
message("Written: ", out_csv)

result_sf <- st_as_sf(result, coords = c("longitude", "latitude"), crs = 4326)
out_gpkg  <- file.path(data_dir, "cassn_gap_status.gpkg")
st_write(result_sf, out_gpkg, delete_dsn = TRUE, quiet = TRUE)
message("Written: ", out_gpkg)

# --- 7. Write lookup table ---
lookup <- joined %>%
  st_drop_geometry() %>%
  mutate(gap_status = suppressWarnings(as.integer(GAP_Sts))) %>%
  filter(!is.na(gap_status)) %>%
  distinct(gap_status, description = d_GAP_Sts) %>%
  arrange(gap_status)

lookup_csv <- file.path(data_dir, "gap_status_lookup.csv")
write_csv(lookup, lookup_csv)
message("Written: ", lookup_csv)

# --- 8. Summary ---
message("\nSummary (", nrow(result), " sites total):")
print(count(result, organization, gap_status) %>% arrange(organization, gap_status), n = 30)
message("\nSites with no PAD-US coverage (No Data): ",
        sum(is.na(result$gap_status)))
