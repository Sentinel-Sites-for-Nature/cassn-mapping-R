#!/usr/bin/env Rscript

# Map clipped ds3271 vegetation polygons over a topo/hydro basemap.

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
  library(ggplot2)
  library(ggspatial)
  library(maptiles)
  library(tidyterra)
  library(viridis)
})

gpkg_path <- file.path(project_root, "data", "ds3271_sagehen_clip.gpkg")
plot_locations_csv <- file.path(project_root, "raw_data", "proposed_plot_locations.csv")
out_dir <- file.path(project_root, "outputs", "maps")

if (!file.exists(gpkg_path)) {
  stop("GeoPackage not found. Run 01_clip_ds3271_to_sagehen.R first: ", gpkg_path)
}
if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
}

veg <- st_read(gpkg_path, layer = "ds3271_sagehen_clip", quiet = TRUE) %>%
  mutate(CalVegType = if_else(is.na(CalVegType) | CalVegType == "", "Unclassified", CalVegType))

veg_wgs <- st_transform(veg, 4326)
veg_3857 <- st_transform(veg, 3857)

plot_locations_3857 <- NULL
if (file.exists(plot_locations_csv)) {
  plot_locations_3857 <- read.csv(plot_locations_csv, stringsAsFactors = FALSE) %>%
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE) %>%
    st_transform(3857)
}

map_extent <- st_as_sfc(st_bbox(veg_wgs)) %>%
  st_as_sf() %>%
  st_buffer(dist = 0.01) %>%
  st_transform(3857)

message("Fetching Esri WorldTopoMap tiles...")
basemap <- get_tiles(
  x = map_extent,
  provider = "Esri.WorldTopoMap",
  zoom = 14,
  crop = TRUE,
  project = TRUE,
  cachedir = file.path(tempdir(), "sagehen_map_tiles"),
  verbose = TRUE
)

vegetation_levels <- c(
  "Riparian corridor",
  "Wet meadow",
  "Dry sagebrush / mountain mahogany scrub",
  "Montane chaparral / manzanita-oak scrub",
  "Herbaceous / open",
  "Dry pine / lower montane conifer forest",
  "Mesic montane conifer forest"
)

vegetation_palette <- c(
  "Riparian corridor" = "#1F9E89",
  "Wet meadow" = "#54C6D4",
  "Dry sagebrush / mountain mahogany scrub" = "#D2B55B",
  "Montane chaparral / manzanita-oak scrub" = "#C87A2A",
  "Herbaceous / open" = "#A6D96A",
  "Dry pine / lower montane conifer forest" = "#4C8C3A",
  "Mesic montane conifer forest" = "#185C7A"
)

# Vegetation grouping logic mirrors 03_create_vegetation_products.R: riparian woody
# types are separated from wet meadow, dry shrub is separated from montane
# chaparral, and conifer forest is split by warmer/drier pine versus mesic
# montane fir/lodgepole/hemlock/white pine conditions.
veg_3857 <- veg_3857 %>%
  mutate(
    vegetation_group = case_when(
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
    vegetation_group = factor(vegetation_group, levels = vegetation_levels)
  )

veg_types <- veg_3857 %>%
  st_drop_geometry() %>%
  count(CalVegType, sort = TRUE) %>%
  pull(CalVegType)

veg_3857 <- veg_3857 %>%
  mutate(CalVegType = factor(CalVegType, levels = veg_types))

palette <- viridis(length(veg_types), option = "turbo", begin = 0.05, end = 0.95)
names(palette) <- veg_types

make_pin_symbols <- function(points, height = 260, width = 170) {
  coords <- st_coordinates(points)
  radius <- width / 2

  pin_geometry <- lapply(seq_len(nrow(points)), function(i) {
    x <- coords[i, 1]
    y <- coords[i, 2]
    center_y <- y + height * 0.58
    angles <- seq(225, -45, length.out = 48) * pi / 180
    lobe <- cbind(
      x + radius * cos(angles),
      center_y + radius * sin(angles)
    )
    st_polygon(list(rbind(c(x, y), lobe, c(x, y))))
  })

  st_sf(st_drop_geometry(points), geometry = st_sfc(pin_geometry, crs = st_crs(points)))
}

make_pin_label_points <- function(points, height = 260) {
  coords <- st_coordinates(points)
  st_sf(
    st_drop_geometry(points),
    geometry = st_sfc(
      lapply(seq_len(nrow(points)), function(i) {
        st_point(c(coords[i, 1], coords[i, 2] + height * 0.58))
      }),
      crs = st_crs(points)
    )
  )
}

make_map <- function(fill_col, fill_palette, legend_title, title,
                     fill_alpha = 0.78, plot_locations = NULL) {
  plot <- ggplot() +
    tidyterra::geom_spatraster_rgb(data = basemap, maxcell = Inf) +
    geom_sf(
      data = veg_3857,
      aes(fill = .data[[fill_col]]),
      color = "white",
      linewidth = 0.08,
      alpha = fill_alpha
    ) +
    geom_sf(
      data = st_union(veg_3857),
      fill = NA,
      color = "#222222",
      linewidth = 0.45
    ) +
    scale_fill_manual(values = fill_palette, name = legend_title, drop = FALSE) +
    annotation_scale(
      location = "bl",
      width_hint = 0.24,
      text_cex = 0.8,
      pad_x = unit(0.35, "in"),
      pad_y = unit(0.28, "in")
    ) +
    annotation_north_arrow(
      location = "tr",
      which_north = "true",
      style = north_arrow_fancy_orienteering,
      height = unit(0.48, "in"),
      width = unit(0.48, "in"),
      pad_x = unit(0.25, "in"),
      pad_y = unit(0.25, "in")
    ) +
    coord_sf(crs = 3857, datum = NA, expand = FALSE) +
    labs(title = title) +
    theme_void(base_size = 12) +
    theme(
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      plot.title = element_text(face = "bold", size = 18, margin = margin(b = 3)),
      legend.position = "right",
      legend.title = element_text(face = "bold", size = 10),
      legend.text = element_text(size = 8),
      legend.key.height = unit(0.18, "in"),
      legend.key.width = unit(0.24, "in"),
      legend.margin = margin(l = 6),
      plot.margin = margin(10, 10, 8, 10)
    ) +
    guides(fill = guide_legend(ncol = 1, override.aes = list(alpha = 0.9, color = NA)))

  if (!is.null(plot_locations)) {
    pin_symbols <- make_pin_symbols(plot_locations)
    pin_labels <- make_pin_label_points(plot_locations)

    plot <- plot +
      geom_sf(
        data = pin_symbols,
        fill = "#D7191C",
        color = "white",
        linewidth = 0.45
      ) +
      geom_sf_text(
        data = pin_labels,
        aes(label = plot_id),
        color = "white",
        fontface = "bold",
        size = 2.8
      )
  }

  plot
}

save_map <- function(plot, filename) {
  out_png <- file.path(out_dir, filename)
  ggsave(out_png, plot, width = 12, height = 8, units = "in", dpi = 300, bg = "white")
  message("Written: ", out_png)
}

save_map(
  make_map(
    "CalVegType",
    palette,
    "Vegetation Type",
    "Sagehen Vegetation Types"
  ),
  "ds3271_sagehen_vegetation_map.png"
)

save_map(
  make_map(
    "vegetation_group",
    vegetation_palette,
    "Habitat Type",
    "Sagehen Vegetation Groups"
  ),
  "ds3271_sagehen_vegetation_groups_map.png"
)

if (!is.null(plot_locations_3857)) {
  save_map(
    make_map(
      "vegetation_group",
      vegetation_palette,
      "Habitat Type",
      "Sagehen Proposed Plot Locations",
      fill_alpha = 0.46,
      plot_locations = plot_locations_3857
    ),
    "sagehen_proposed_plot_locations_map.png"
  )
}
