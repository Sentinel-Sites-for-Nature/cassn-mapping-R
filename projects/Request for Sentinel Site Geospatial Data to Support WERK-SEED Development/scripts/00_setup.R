#!/usr/bin/env Rscript

# Install and load required packages for this project.

cwd <- getwd()
project_name <- "Request for Sentinel Site Geospatial Data to Support WERK-SEED Development"
project_root <- if (basename(cwd) == "scripts") {
  normalizePath(file.path(cwd, ".."), mustWork = FALSE)
} else if (basename(cwd) == project_name) {
  normalizePath(cwd, mustWork = FALSE)
} else {
  normalizePath(file.path(cwd, "projects", project_name), mustWork = FALSE)
}
project_lib <- file.path(project_root, ".Rlib")

packages <- c(
  "sf",
  "dplyr",
  "ggplot2",
  "tigris",
  "rmapshaper",
  "rnaturalearth",
  "elevatr",
  "terra"
)

missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  if (!dir.exists(project_lib)) {
    dir.create(project_lib, recursive = TRUE, showWarnings = FALSE)
  }
  .libPaths(c(project_lib, .libPaths()))
  install.packages(missing, repos = "https://cloud.r-project.org", lib = project_lib)
}

invisible(lapply(packages, library, character.only = TRUE))

message("Loaded packages: ", paste(packages, collapse = ", "))
message("R version: ", R.version.string)
