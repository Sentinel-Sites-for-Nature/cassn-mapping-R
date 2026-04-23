# Request for Sentinel Site Geospatial Data to Support WERK-SEED Development

Project created to package UC CA-SSN point and polygon shapefiles and provide quick sample maps for sharing in response to a geospatial data request.

## Contents

- `data/` - local copies of the shapefile components, organized into one folder per shapefile dataset
- `scripts/00_setup.R` - installs required R packages into a project-local `.Rlib`
- `scripts/01_sample_maps.qmd` - renders two simple static maps using the same California hillshade/lakes basemap pattern as `projects/gap-maps`
- `sample_maps/` - rendered PNG map outputs

## Data files

- `data/uc_cassn_points_sites/uc_cassn_points_sites.shp` - UC sentinel site point layer
- `data/uc_cassn_polygons_sites/uc_cassn_polygons_sites.shp` - UC reserve boundary polygon layer
- `data/intensive_data_colelction_site_polygons/intensive_data_colelction_site_polygons.shp` - polygon subset for Angelo, Bodega, Cahill, Jepson, McLaughlin, and Quail intensive data collection sites

## Notes

- 5 sentinel site reserves currently do not have corresponding polygons in the supplied UC NRS polygon source. Those polygons can be added later if and when they become available.
- `data/intensive_data_colelction_site_polygons/intensive_data_colelction_site_polygons.shp` identifies the six intensive data collection sites where year-round monitoring is being conducted: Angelo, Bodega, Cahill, Jepson, McLaughlin, and Quail.

## Render

From the repo root:

```bash
Rscript "projects/Request for Sentinel Site Geospatial Data to Support WERK-SEED Development/scripts/00_setup.R"
quarto render "projects/Request for Sentinel Site Geospatial Data to Support WERK-SEED Development/scripts/01_sample_maps.qmd"
```

Rendered PNGs are written to `sample_maps/`.
