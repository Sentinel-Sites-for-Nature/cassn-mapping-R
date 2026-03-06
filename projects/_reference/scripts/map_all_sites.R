#!/usr/bin/env Rscript

# Static map of all CA-SSN sentinel sites, colored by partner organization.
# Output: outputs/maps/all_sites.png

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
  library(ggplot2)
  library(tigris)
  library(rmapshaper)
  library(gridExtra)
  library(grid)
})

gpkg_path <- file.path(project_root, "data", "CASSN_all_sites.gpkg")
out_dir   <- file.path(project_root, "outputs", "maps")

if (!file.exists(gpkg_path)) stop("GeoPackage not found. Run convert_all_sites_to_spatial.R first: ", gpkg_path)
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

sites_sf <- st_read(gpkg_path, layer = "cassn_all_sites", quiet = TRUE)
message("Loaded ", nrow(sites_sf), " sites")

# --- Organization factor order and palette ---
org_levels <- c("CDFW", "UCNRS", "CSU", "TNC", "Pepperwood")

org_palette <- c(
  "CDFW"       = "#2166AC",
  "UCNRS"      = "#1B7837",
  "CSU"        = "#D6604D",
  "TNC"        = "#762A83",
  "Pepperwood" = "#B8860B"
)

sites_sf$organization <- factor(sites_sf$organization, levels = org_levels)

# --- California outline ---
options(tigris_use_cache = TRUE)
ca <- tigris::states(cb = TRUE, year = 2023, class = "sf") |>
  filter(NAME == "California") |>
  st_transform(st_crs(sites_sf))

ca <- rmapshaper::ms_simplify(ca, keep = 0.08, keep_shapes = TRUE)

# --- Map (no legend) ---
map_plot <- ggplot() +
  geom_sf(data = ca, fill = "white", color = "#BFC5C8", linewidth = 0.4) +
  geom_sf(
    data  = sites_sf,
    aes(color = organization),
    size  = 2.2,
    alpha = 0.9
  ) +
  scale_color_manual(
    values = org_palette,
    limits = org_levels,
    drop   = FALSE,
    name   = "Organization"
  ) +
  coord_sf() +
  labs(
    title    = "California Sentinel Sites for Nature (CA-SSN)",
    subtitle = "Planned and existing sites"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid      = element_blank(),
    axis.title      = element_blank(),
    axis.text       = element_blank(),
    legend.position = "none",
    plot.title      = element_text(face = "bold", size = 16, hjust = 0.1),
    plot.subtitle   = element_text(size = 13, hjust = 0.1, color = "#555555")
  )

# --- Extract legend from a legend-bearing version ---
legend_plot      <- map_plot + theme(legend.position = "right",
                                     legend.text     = element_text(size = 12),
                                     legend.title    = element_text(size = 13, face = "bold"))
legend_grob_full <- ggplotGrob(legend_plot)
guide_idx        <- which(grepl("guide", legend_grob_full$layout$name))
legend_grob      <- legend_grob_full$grobs[[guide_idx[1]]]

# --- Site counts table by organization (with total row) ---
counts_df <- sites_sf |>
  st_drop_geometry() |>
  count(organization, .drop = FALSE) |>
  mutate(organization = factor(organization, levels = org_levels)) |>
  arrange(organization) |>
  rename(Organization = organization, `# Sites` = n)

total_row <- data.frame(Organization = "Total", `# Sites` = sum(counts_df$`# Sites`), check.names = FALSE)
counts_df <- bind_rows(counts_df, total_row)

# Row fills: alternating white/#F5F5F5 for org rows, darker for Total
n_org <- nrow(counts_df) - 1L
row_fills    <- c(rep(c("white", "#F5F5F5"), length.out = n_org), "#BEBEBE")
row_fontface <- c(rep("plain", n_org), "bold")

table_grob <- gridExtra::tableGrob(
  counts_df,
  rows  = NULL,
  theme = gridExtra::ttheme_minimal(
    core = list(
      fg_params = list(fontsize = 13, fontface = row_fontface),
      bg_params = list(fill = row_fills)
    ),
    colhead = list(
      fg_params = list(fontsize = 13, fontface = "bold"),
      bg_params = list(fill = "#EFEFEF")
    ),
    padding = grid::unit(c(3, 3), "mm")
  )
)

# --- Compose layout: map | (legend + table) ---
right_panel <- gridExtra::arrangeGrob(
  legend_grob,
  table_grob,
  ncol    = 1,
  heights = c(1.5, 1)
)

panel <- gridExtra::arrangeGrob(
  map_plot,
  right_panel,
  ncol   = 2,
  widths = c(2.8, 2.2)
)

# --- Save ---
out_path <- file.path(out_dir, "all_sites.png")
ggsave(
  filename = out_path,
  plot     = panel,
  width    = 11,
  height   = 8.5,
  dpi      = 300
)
message("Written: ", out_path)
