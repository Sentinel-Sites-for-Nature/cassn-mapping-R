#!/usr/bin/env Rscript

# Create the derived Sagehen ecotone products from the clipped ds3271 layer.

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

data_dir <- file.path(project_root, "data")
source_gpkg <- file.path(data_dir, "ds3271_sagehen_clip.gpkg")

if (!file.exists(source_gpkg)) {
  stop("GeoPackage not found. Run 01_clip_ds3271_to_sagehen.R first: ", source_gpkg)
}

ecotone_levels <- c(
  "Riparian corridor",
  "Wet meadow",
  "Dry sagebrush / mountain mahogany scrub",
  "Montane chaparral / manzanita-oak scrub",
  "Herbaceous / open",
  "Dry pine / lower montane conifer forest",
  "Mesic montane conifer forest"
)

ecotone_palette <- c(
  "Riparian corridor" = "#1F9E89",
  "Wet meadow" = "#54C6D4",
  "Dry sagebrush / mountain mahogany scrub" = "#D2B55B",
  "Montane chaparral / manzanita-oak scrub" = "#C87A2A",
  "Herbaceous / open" = "#A6D96A",
  "Dry pine / lower montane conifer forest" = "#4C8C3A",
  "Mesic montane conifer forest" = "#185C7A"
)

# Ecotone grouping logic:
# - Woody mesic corridor types are separated from wet meadows because willow,
#   alder, and aspen add vertical structure, cover, and edge habitat that open
#   meadow polygons do not.
# - Dry sagebrush / mountain mahogany scrub captures the drier eastside/Great
#   Basin shrub and open woodland signal.
# - Montane chaparral / manzanita-oak scrub captures denser sclerophyll shrub
#   and post-disturbance montane shrubfield structure.
# - Conifer forest is split into a warmer, drier pine-dominated group and a
#   mesic montane fir/lodgepole/hemlock/white pine group because those
#   gradients matter for terrestrial vertebrate habitat structure, snowpack,
#   canopy conditions, and understory composition.
veg <- st_read(source_gpkg, layer = "ds3271_sagehen_clip", quiet = TRUE) %>%
  st_make_valid() %>%
  mutate(
    CalVegType = if_else(is.na(CalVegType) | CalVegType == "", "Unclassified", CalVegType),
    ecotone = case_when(
      CalVegType %in% c("Mountain Alder", "Willow (Shrub)", "Quaking Aspen") ~
        "Riparian corridor",
      CalVegType == "Wet Meadows" ~
        "Wet meadow",
      CalVegType %in% c("Basin Sagebrush", "Bitterbrush - Sagebrush", "Curlleaf Mountain Mahogany (tree)") ~
        "Dry sagebrush / mountain mahogany scrub",
      CalVegType %in% c("Snowbrush", "Greenleaf Manzanita", "Pinemat Manzanita", "Huckleberry Oak") ~
        "Montane chaparral / manzanita-oak scrub",
      CalVegType %in% c("Perennial Grasses and Forbs", "Alpine Grasses and Forbs", "Barren") ~
        "Herbaceous / open",
      CalVegType %in% c("Jeffrey Pine", "Eastside Pine") ~
        "Dry pine / lower montane conifer forest",
      CalVegType %in% c("White Fir", "Red Fir", "Lodgepole Pine", "Mountain Hemlock", "Western White Pine") ~
        "Mesic montane conifer forest",
      TRUE ~ "Herbaceous / open"
    ),
    ecotone = factor(ecotone, levels = ecotone_levels),
    source_polygon_acres = as.numeric(st_area(.)) * 0.000247105381
  )

ecotone_gpkg <- file.path(data_dir, "ds3271_sagehen_ecotones.gpkg")
ecotone_earth_gpkg <- file.path(data_dir, "ds3271_sagehen_ecotones_google_earth.gpkg")
ecotone_kml <- file.path(data_dir, "ds3271_sagehen_ecotones.kml")
ecotone_kmz <- file.path(data_dir, "ds3271_sagehen_ecotones.kmz")

ecotone_product <- veg %>%
  group_by(ecotone) %>%
  summarise(
    source_polygon_count = n(),
    source_vegetation_types = paste(sort(unique(CalVegType)), collapse = "; "),
    clipped_acres = sum(source_polygon_acres),
    clipped_hectares = clipped_acres * 0.404685642,
    .groups = "drop"
  ) %>%
  arrange(factor(ecotone, levels = ecotone_levels)) %>%
  mutate(
    ecotone_class = as.integer(factor(ecotone, levels = ecotone_levels)),
    ecotone = as.character(ecotone)
  ) %>%
  select(ecotone_class, ecotone, source_polygon_count, source_vegetation_types,
         clipped_acres, clipped_hectares) %>%
  st_collection_extract("POLYGON", warn = FALSE) %>%
  st_cast("MULTIPOLYGON", warn = FALSE) %>%
  st_make_valid()

st_write(
  ecotone_product,
  ecotone_gpkg,
  layer = "ds3271_sagehen_ecotones",
  delete_dsn = TRUE,
  quiet = TRUE
)
message("Written: ", ecotone_gpkg)

# Google Earth renders KML/KMZ most reliably when the source polygons remain
# separate. The dissolved analysis GeoPackage can create very complex multipart
# forest geometries with many holes, so the Earth export keeps one placemark per
# clipped source polygon and groups those placemarks into ecotone folders.
ecotone_earth <- veg %>%
  mutate(
    ecotone_class = as.integer(factor(ecotone, levels = ecotone_levels)),
    ecotone = as.character(ecotone),
    source_vegetation_type = CalVegType,
    clipped_acres = source_polygon_acres,
    clipped_hectares = clipped_acres * 0.404685642
  ) %>%
  select(ecotone_class, ecotone, source_vegetation_type, clipped_acres, clipped_hectares) %>%
  st_collection_extract("POLYGON", warn = FALSE) %>%
  st_cast("MULTIPOLYGON", warn = FALSE) %>%
  st_make_valid()

st_write(
  ecotone_earth,
  ecotone_earth_gpkg,
  layer = "ds3271_sagehen_ecotones_google_earth",
  delete_dsn = TRUE,
  quiet = TRUE
)
message("Written: ", ecotone_earth_gpkg)

ecotone_earth_wgs <- ecotone_earth %>%
  st_transform(4326) %>%
  arrange(ecotone_class, source_vegetation_type)

hex_to_kml_color <- function(hex, alpha = "B3") {
  rgb <- grDevices::col2rgb(hex)
  paste0(alpha, sprintf("%02X%02X%02X", rgb[3], rgb[2], rgb[1]))
}

add_ring <- function(parent, node_name, ring) {
  ring_node <- xml_add_child(parent, node_name)
  linear_ring <- xml_add_child(ring_node, "LinearRing")
  coords <- paste(sprintf("%.8f,%.8f,0", ring[, 1], ring[, 2]), collapse = " ")
  xml_add_child(linear_ring, "coordinates", coords)
}

add_polygon <- function(parent, polygon) {
  polygon_node <- xml_add_child(parent, "Polygon")
  xml_add_child(polygon_node, "tessellate", "1")
  add_ring(polygon_node, "outerBoundaryIs", polygon[[1]])
  if (length(polygon) > 1) {
    for (ring in polygon[-1]) add_ring(polygon_node, "innerBoundaryIs", ring)
  }
}

add_geometry <- function(parent, geometry) {
  geom_class <- class(geometry)[2]
  if (geom_class == "MULTIPOLYGON") {
    multi_node <- xml_add_child(parent, "MultiGeometry")
    for (polygon in unclass(geometry)) add_polygon(multi_node, polygon)
  } else if (geom_class == "POLYGON") {
    add_polygon(parent, unclass(geometry))
  } else {
    stop("Unsupported geometry type for KML export: ", geom_class, call. = FALSE)
  }
}

kml_doc <- xml_new_root("kml", xmlns = "http://www.opengis.net/kml/2.2")
doc_node <- xml_add_child(kml_doc, "Document")
xml_add_child(doc_node, "name", "Sagehen vegetation ecotones")

for (ecotone in ecotone_levels) {
  style_id <- paste0("ecotone_", match(ecotone, ecotone_levels))
  style_node <- xml_add_child(doc_node, "Style", id = style_id)
  line_style <- xml_add_child(style_node, "LineStyle")
  xml_add_child(line_style, "color", "ff333333")
  xml_add_child(line_style, "width", "1")
  poly_style <- xml_add_child(style_node, "PolyStyle")
  xml_add_child(poly_style, "color", hex_to_kml_color(ecotone_palette[[ecotone]]))
  xml_add_child(poly_style, "fill", "1")
  xml_add_child(poly_style, "outline", "1")
}

for (ecotone in ecotone_levels) {
  folder <- xml_add_child(doc_node, "Folder")
  xml_add_child(folder, "name", ecotone)
  class_data <- ecotone_earth_wgs %>% filter(.data$ecotone == .env$ecotone)
  for (i in seq_len(nrow(class_data))) {
    attrs <- st_drop_geometry(class_data[i, ])
    placemark <- xml_add_child(folder, "Placemark")
    xml_add_child(
      placemark,
      "name",
      paste(attrs$ecotone, attrs$source_vegetation_type, sep = " - ")
    )
    xml_add_child(placemark, "styleUrl", paste0("#ecotone_", attrs$ecotone_class))
    ext <- xml_add_child(placemark, "ExtendedData")
    for (field in c("ecotone_class", "ecotone", "source_vegetation_type", "clipped_acres", "clipped_hectares")) {
      data_node <- xml_add_child(ext, "Data", name = field)
      xml_add_child(data_node, "value", as.character(attrs[[field]]))
    }
    add_geometry(placemark, st_geometry(class_data)[[i]])
  }
}

write_xml(kml_doc, ecotone_kml, options = "format")

kmz_tmp <- file.path(tempdir(), "sagehen_ecotones_kmz")
if (dir.exists(kmz_tmp)) unlink(kmz_tmp, recursive = TRUE)
dir.create(kmz_tmp, recursive = TRUE)
invisible(file.copy(ecotone_kml, file.path(kmz_tmp, "doc.kml"), overwrite = TRUE))
if (file.exists(ecotone_kmz)) unlink(ecotone_kmz)
old_wd <- setwd(kmz_tmp)
on.exit(setwd(old_wd), add = TRUE)
utils::zip(ecotone_kmz, files = "doc.kml", flags = "-q")
setwd(old_wd)

message("Written: ", ecotone_kml)
message("Written: ", ecotone_kmz)
