#!/usr/bin/env Rscript

# Build the deployment GeoPackage by combining reserve coordinates with status data.

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
})

cwd <- getwd()
project_root <- if (basename(cwd) == "scripts") {
  normalizePath(file.path(cwd, ".."), mustWork = FALSE)
} else {
  normalizePath(file.path(cwd, "projects", "2026-03_ssn-deployment"), mustWork = FALSE)
}

raw_dir  <- file.path(project_root, "data_raw")
data_dir <- file.path(project_root, "data")

if (!dir.exists(data_dir)) {
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
}

# --- 1. Read reserves coordinate table ---
reserves_path <- file.path(raw_dir, "ucnrs_reserves.csv")
if (!file.exists(reserves_path)) stop("Missing: ", reserves_path)

reserves <- read_csv(reserves_path, show_col_types = FALSE)
message("Read ", nrow(reserves), " reserves from ucnrs_reserves.csv")

# --- 2. Create sf point object (WGS 84) ---
reserves_sf <- st_as_sf(reserves, coords = c("longitude", "latitude"), crs = 4326)

# --- 3. Read deployment status table ---
status_path <- file.path(raw_dir, "ucnrs_deployment_status.csv")
if (!file.exists(status_path)) stop("Missing: ", status_path)

status <- read_csv(status_path, show_col_types = FALSE)
message("Read ", nrow(status), " rows from ucnrs_deployment_status.csv")

# --- 4. Warn on any unmatched names ---
unmatched_reserves <- setdiff(reserves$reserve_name, status$reserve_name)
unmatched_status   <- setdiff(status$reserve_name, reserves$reserve_name)

if (length(unmatched_reserves) > 0) {
  warning("Reserves with no matching status row: ", paste(unmatched_reserves, collapse = "; "))
}
if (length(unmatched_status) > 0) {
  warning("Status rows with no matching reserve geometry: ", paste(unmatched_status, collapse = "; "))
}

# --- 5. Join and coerce status to ordered factor ---
status_levels <- c(
  "Not yet visited",
  "Infrastructure set up",
  "Collecting data (1st round)",
  "Collecting data (2nd round)"
)

deployment_sf <- reserves_sf %>%
  left_join(status, by = "reserve_name") %>%
  mutate(
    status = factor(
      if_else(is.na(status), "Not yet visited", status),
      levels = status_levels,
      ordered = TRUE
    )
  )

message("Final feature count: ", nrow(deployment_sf))
message("Status breakdown:")
print(table(deployment_sf$status))

# --- 6. Write GeoPackage ---
gpkg_path <- file.path(data_dir, "ucnrs_deployment.gpkg")
st_write(deployment_sf, gpkg_path, layer = "ucnrs_deployment", delete_layer = TRUE, quiet = TRUE)
message("Written: ", gpkg_path)
