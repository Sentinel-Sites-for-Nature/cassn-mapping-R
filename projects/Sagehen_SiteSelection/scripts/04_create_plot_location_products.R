#!/usr/bin/env Rscript

# Create derived GIS and Google Earth products for proposed plot locations.

cwd <- getwd()
project_root <- if (basename(cwd) == "scripts") {
  normalizePath(file.path(cwd, ".."), mustWork = FALSE)
} else if (basename(cwd) == "Sagehen_SiteSelection") {
  normalizePath(cwd, mustWork = FALSE)
} else {
  normalizePath(file.path(cwd, "projects", "Sagehen_SiteSelection"), mustWork = FALSE)
}

project_lib <- file.path(project_root, ".Rlib")
if (dir.exists(project_lib)) .libPaths(c(project_lib, .libPaths()))

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(xml2)
})

raw_csv <- file.path(project_root, "raw_data", "proposed_plot_locations.csv")
data_dir <- file.path(project_root, "data")

if (!file.exists(raw_csv)) {
  stop("Proposed plot CSV not found: ", raw_csv)
}

plots_gpkg <- file.path(data_dir, "sagehen_proposed_plot_locations.gpkg")
plots_kml <- file.path(data_dir, "sagehen_proposed_plot_locations.kml")
plots_kmz <- file.path(data_dir, "sagehen_proposed_plot_locations.kmz")

plots <- read.csv(raw_csv, stringsAsFactors = FALSE) %>%
  mutate(
    plot_id = as.integer(plot_id),
    plot_label = paste0("Plot ", plot_id),
    habitat_type = proposed_habitat
  ) %>%
  select(plot_id, plot_label, habitat_type, latitude, longitude, coordinate_dms) %>%
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)

st_write(
  plots,
  plots_gpkg,
  layer = "sagehen_proposed_plot_locations",
  delete_dsn = TRUE,
  quiet = TRUE
)
message("Written: ", plots_gpkg)

kml_doc <- xml_new_root("kml", xmlns = "http://www.opengis.net/kml/2.2")
doc_node <- xml_add_child(kml_doc, "Document")
xml_add_child(doc_node, "name", "Sagehen proposed plot locations")

style_node <- xml_add_child(doc_node, "Style", id = "plot_pin")
icon_style <- xml_add_child(style_node, "IconStyle")
xml_add_child(icon_style, "scale", "1.1")
icon <- xml_add_child(icon_style, "Icon")
xml_add_child(icon, "href", "http://maps.google.com/mapfiles/kml/paddle/red-circle.png")

plots_df <- st_drop_geometry(plots)
for (i in seq_len(nrow(plots_df))) {
  placemark <- xml_add_child(doc_node, "Placemark")
  xml_add_child(placemark, "name", plots_df$plot_label[i])
  xml_add_child(placemark, "styleUrl", "#plot_pin")
  ext <- xml_add_child(placemark, "ExtendedData")
  for (field in c("plot_id", "plot_label", "habitat_type", "latitude", "longitude", "coordinate_dms")) {
    data_node <- xml_add_child(ext, "Data", name = field)
    xml_add_child(data_node, "value", as.character(plots_df[[field]][i]))
  }
  point_node <- xml_add_child(placemark, "Point")
  xml_add_child(
    point_node,
    "coordinates",
    sprintf("%.8f,%.8f,0", plots_df$longitude[i], plots_df$latitude[i])
  )
}

write_xml(kml_doc, plots_kml, options = "format")

kmz_tmp <- file.path(tempdir(), "sagehen_proposed_plot_locations_kmz")
if (dir.exists(kmz_tmp)) unlink(kmz_tmp, recursive = TRUE)
dir.create(kmz_tmp, recursive = TRUE)
invisible(file.copy(plots_kml, file.path(kmz_tmp, "doc.kml"), overwrite = TRUE))
if (file.exists(plots_kmz)) unlink(plots_kmz)
old_wd <- setwd(kmz_tmp)
on.exit(setwd(old_wd), add = TRUE)
utils::zip(plots_kmz, files = "doc.kml", flags = "-q")
setwd(old_wd)

message("Written: ", plots_kml)
message("Written: ", plots_kmz)
