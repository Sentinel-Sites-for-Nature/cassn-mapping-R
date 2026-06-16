# Sagehen Site Selection

This project processes CalVeg ds3271 vegetation data for the Sagehen boundary
and derives broader vegetation ecotone products for site-selection work.

## Inputs

- `raw_data/ds3271/ds3271.gdb`: source CalVeg vegetation geodatabase.
- `raw_data/Sagehen.kmz`: Sagehen boundary used to clip the vegetation data.
- `raw_data/proposed_plot_locations.csv`: proposed plot locations for five
  target habitat types, stored with the original DMS coordinates and decimal
  latitude/longitude for mapping.

The source `ds3271.gdb` is intentionally not committed because it contains a
large source table that exceeds GitHub's normal file-size limits. The clipped
and derived Sagehen products are committed under `data/`.

The boundary KMZ contains one polygon feature only. It does not distinguish a
core reserve property from a broader Sagehen Experimental Forest property.

## Processed Data

- `data/ds3271_sagehen_clip.gpkg`: ds3271 vegetation polygons clipped to the
  Sagehen boundary. This is a vector clip operation, equivalent to the ArcGIS Pro
  **Clip** geoprocessing tool.
- `data/ds3271_sagehen_ecotones.gpkg`: dissolved 7-group ecotone product for
  GIS analysis.
- `data/ds3271_sagehen_ecotones_google_earth.gpkg`: undissolved 7-group ecotone
  polygon product used as the source for Google Earth export.
- `data/ds3271_sagehen_ecotones.kmz`: Google Earth-ready KMZ export. This
  version is intentionally **not dissolved**: it keeps one placemark per source
  polygon, grouped into ecotone folders, so Google Earth does not have to render
  single complex multipart forest polygons with many holes. KMZ/KML is
  preferable to GeoPackage for Google Earth because it is the application's
  native vector overlay format and uses WGS 84 coordinates.
- `data/ds3271_sagehen_ecotones.kml`: uncompressed Google Earth KML version of
  the same 7-group product. Use this if a Google Earth surface has trouble with
  compressed KMZ uploads.

## Ecotone Grouping Logic

The source `CalVegType` classes are too detailed for initial site-selection
screening, so they are grouped into broader ecotones. The current product uses
one 7-group crosswalk.

| Ecotone | Source `CalVegType` values | Reasoning |
| --- | --- | --- |
| Riparian corridor | Mountain Alder; Willow (Shrub); Quaking Aspen | Woody mesic corridor types with vertical structure, cover, and edge habitat. Aspen is treated as a mesic corridor indicator in this Sagehen context rather than as a broad upland forest type. |
| Wet meadow | Wet Meadows | Open herbaceous wet meadow is kept separate from woody riparian corridor because hydrology is shared but structure and vertebrate habitat use differ. |
| Dry sagebrush / mountain mahogany scrub | Basin Sagebrush; Bitterbrush - Sagebrush; Curlleaf Mountain Mahogany (tree) | Drier open shrub/woodland types with Great Basin/eastside affinity. |
| Montane chaparral / manzanita-oak scrub | Snowbrush; Greenleaf Manzanita; Pinemat Manzanita; Huckleberry Oak | Denser montane shrubfield and sclerophyll scrub structure, distinct from drier sagebrush/mahogany scrub. |
| Herbaceous / open | Perennial Grasses and Forbs; Alpine Grasses and Forbs; Barren | Non-wet herbaceous openings and sparse-cover areas. |
| Dry pine / lower montane conifer forest | Jeffrey Pine; Eastside Pine | Warmer, drier pine-dominated conifer conditions. This separates lower montane/eastside pine habitat from mesic fir and lodgepole conditions. |
| Mesic montane conifer forest | White Fir; Red Fir; Lodgepole Pine; Mountain Hemlock; Western White Pine | Relatively moist montane conifer conditions. The split matters for terrestrial vertebrate habitat because it tracks canopy structure, snowpack, temperature, moisture, and understory differences while avoiding an over-specific upper-montane label for White Fir. |

## Scripts

- `scripts/01_clip_ds3271_to_sagehen.R`: clips ds3271 to the Sagehen boundary.
- `scripts/02_map_ds3271_sagehen.R`: renders detailed vegetation and 7-group
  ecotone maps over an Esri topographic basemap.
- `scripts/03_create_ecotone_products.R`: creates dissolved 7-group ecotone
  GeoPackage output plus undissolved KML/KMZ exports for Google Earth.

## Outputs

Maps are written to `outputs/maps/`:

- `ds3271_sagehen_vegetation_map.png`
- `ds3271_sagehen_ecotones_map.png`
- `ds3271_sagehen_ecotones_proposed_plots_map.png`
