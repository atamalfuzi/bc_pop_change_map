# bc_pop_change_map

Maps of absolute population change across British Columbia's municipalities: estimated change from 2003 to 2023, and projected change from 2023 to 2046. Each map has an inset zoomed on Metro Vancouver, where most of the growth is concentrated.

![Population change 2003-2023](maps/change_23_03.png)

![Projected population change 2023-2046](maps/change_46_23.png)

## Data

[BC Sub-Provincial Population Estimates and Projections](https://catalogue.data.gov.bc.ca/dataset/bc-sub-provincial-population-estimates-and-projections), Municipalities (Census Subdivisions) table. The script downloads it directly, so there's nothing to set up. Boundaries come from the [bcmaps](https://github.com/bcgov/bcmaps) package (2021 census subdivisions, clipped to the coastline).

Areas outside municipalities are published as one "Unincorporated Areas" total per regional district, so the script merges those census subdivisions into a single polygon per regional district before joining.

Contains information licensed under the [Open Government Licence – British Columbia](https://www2.gov.bc.ca/gov/content/data/policy-standards/open-data/open-government-licence-bc).

## Run it

```r
install.packages(c("sf", "bcmaps", "ggplot2", "dplyr", "tidyr", "readr", "cowplot"))
source("code.R")
```

The maps are written to `maps/`. The first run downloads the boundary files (a few minutes); bcmaps caches them after that.

## License

Code: [MIT](LICENSE).
