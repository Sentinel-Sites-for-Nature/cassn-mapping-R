#!/usr/bin/env Rscript

# Clip the ds3271 vegetation polygons to the Sagehen boundary.

cwd <- getwd()
project_root <- if (basename(cwd) == "scripts") {
  normalizePath(file.path(cwd, ".."), mustWork = FALSE)
} else if (basename(cwd) == "Sagehen_SiteSelection") {
  normalizePath(cwd, mustWork = FALSE)
} else {
  normalizePath(file.path(cwd, "projects", "Sagehen_SiteSelection"), mustWork = FALSE)
}

raw_dir  <- file.path(project_root, "raw_data")
data_dir <- file.path(project_root, "data")

if (!dir.exists(data_dir)) {
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
}

ds3271_gdb <- file.path(raw_dir, "ds3271", "ds3271.gdb")
boundary_kmz <- file.path(raw_dir, "Sagehen.kmz")
if (!file.exists(boundary_kmz)) {
  boundary_kmz <- file.path(project_root, "Sagehen.kmz")
}

if (!dir.exists(ds3271_gdb)) stop("Missing: ", ds3271_gdb)
if (!file.exists(boundary_kmz)) stop("Missing: ", boundary_kmz)

ds_layer <- "ds3271"
boundary_layer <- "Sagehen_Boundary_04_27_2012_1"

boundary_tmp <- file.path(tempdir(), "sagehen_boundary")
if (!dir.exists(boundary_tmp)) dir.create(boundary_tmp, recursive = TRUE)
unzip(boundary_kmz, files = "doc.kml", exdir = boundary_tmp, overwrite = TRUE)

boundary_kml <- file.path(boundary_tmp, "doc.kml")
boundary_gpkg <- file.path(boundary_tmp, "sagehen_boundary.gpkg")
out_gpkg <- file.path(data_dir, "ds3271_sagehen_clip.gpkg")

run_ogr <- function(args) {
  status <- system2("ogr2ogr", args = args)
  if (!identical(status, 0L)) {
    stop("ogr2ogr failed with status ", status, call. = FALSE)
  }
}

message("Preparing Sagehen boundary clip layer...")
run_ogr(c(
  "-f", "GPKG",
  boundary_gpkg,
  boundary_kml,
  boundary_layer,
  "-nln", "sagehen_boundary",
  "-nlt", "PROMOTE_TO_MULTI",
  "-dim", "XY",
  "-overwrite"
))

message("Clipping ds3271 polygons to Sagehen boundary...")
run_ogr(c(
  "-f", "GPKG",
  out_gpkg,
  ds3271_gdb,
  ds_layer,
  "-clipsrc", boundary_gpkg,
  "-clipsrclayer", "sagehen_boundary",
  "-nln", "ds3271_sagehen_clip",
  "-nlt", "PROMOTE_TO_MULTI",
  "-dim", "XY",
  "-makevalid",
  "-overwrite"
))

message("Written: ", out_gpkg)
