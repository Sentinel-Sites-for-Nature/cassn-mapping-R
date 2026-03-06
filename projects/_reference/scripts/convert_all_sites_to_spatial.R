#!/usr/bin/env Rscript

# Convert CASSN_all_sites.csv to a GeoPackage with point geometry.

cwd <- getwd()
project_root <- if (basename(cwd) == "scripts") {
  normalizePath(file.path(cwd, ".."), mustWork = FALSE)
} else if (basename(cwd) == "_reference") {
  normalizePath(cwd, mustWork = FALSE)
} else {
  normalizePath(file.path(cwd, "projects", "_reference"), mustWork = FALSE)
}

project_lib <- file.path(project_root, ".Rlib")
if (dir.exists(project_lib)) .libPaths(c(project_lib, .libPaths()))

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
})

raw_dir  <- file.path(project_root, "data_raw")
data_dir <- file.path(project_root, "data")

if (!dir.exists(data_dir)) {
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
}

# --- 1. Read master site table ---
csv_path <- file.path(raw_dir, "CASSN_all_sites.csv")
if (!file.exists(csv_path)) stop("Missing: ", csv_path)

sites <- read_csv(csv_path, show_col_types = FALSE)
message("Read ", nrow(sites), " rows from CASSN_all_sites.csv")

# --- 2. Validate ---
message("\nSite count by organization:")
print(count(sites, organization))

missing_coords <- sites %>% filter(is.na(latitude) | is.na(longitude))
if (nrow(missing_coords) > 0) {
  warning(nrow(missing_coords), " site(s) dropped due to missing coordinates:")
  warning(paste(" -", missing_coords$site_name, collapse = "\n"))
  sites <- sites %>% filter(!is.na(latitude) & !is.na(longitude))
}

# --- 3. Convert to sf points (WGS 84) ---
sites_sf <- st_as_sf(sites, coords = c("longitude", "latitude"), crs = 4326)
message("\nFinal feature count: ", nrow(sites_sf))

# --- 4. Write GeoPackage ---
gpkg_path <- file.path(data_dir, "CASSN_all_sites.gpkg")
st_write(sites_sf, gpkg_path, layer = "cassn_all_sites", delete_layer = TRUE, quiet = TRUE)
message("Written: ", gpkg_path)
