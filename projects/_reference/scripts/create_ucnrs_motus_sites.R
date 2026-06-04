library(sf)
library(dplyr)
library(readr)

motus_names <- c(
  "Angelo Coast Range Reserve",
  "Landels-Hill Big Creek Reserve",
  "Boyd Deep Canyon Desert Research Center",
  "Burns Piñon Ridge Reserve",
  "Sweeney Granite Mountains Desert Research Center",
  "Lassen Field Station",
  "McLaughlin Natural Reserve",
  "Merced Vernal Pools and Grassland Reserve",
  "Quail Ridge Reserve",
  "Sagehen Creek Field Station",
  "Año Nuevo Island Reserve",
  "Sedgwick Reserve",
  "Sierra Nevada Aquatic Research Laboratory",
  "Strathearn Ranch Reserve",
  "White Mountain Research Center",
  "Stunt Ranch Santa Monica Mountains Reserve"
)

script_dir <- tryCatch(dirname(rstudioapi::getSourceEditorContext()$path), error = function(e) ".")
if (file.exists(file.path(script_dir, "../data_raw/CASSN_all_sites.csv"))) {
  base <- file.path(script_dir, "..")
} else if (file.exists("data_raw/CASSN_all_sites.csv")) {
  base <- "."
} else {
  base <- "projects/_reference"
}

sites <- read_csv(file.path(base, "data_raw/CASSN_all_sites.csv"), show_col_types = FALSE)

motus_sites <- sites |>
  filter(site_name %in% motus_names) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)

if (nrow(motus_sites) != length(motus_names)) {
  missing <- setdiff(motus_names, motus_sites$site_name)
  warning("Unmatched sites: ", paste(missing, collapse = ", "))
}

out_path <- file.path(base, "data/ucnrs_motus_sites.gpkg")
st_write(motus_sites, out_path, delete_dsn = TRUE)

message("Wrote ", nrow(motus_sites), " sites to ", out_path)
