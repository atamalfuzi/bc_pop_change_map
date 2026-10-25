# Loading Required Libraries ----
library(dplyr)
library(tidyr)
library(readr)
library(sf)
library(bcmaps)
library(ggplot2)
library(cowplot)

# Data ----
# BC Sub-Provincial Population Estimates and Projections, Municipalities (Census Subdivisions)
# Open Government Licence - British Columbia
pop_url <- "https://catalogue.data.gov.bc.ca/dataset/86839277-986a-4a29-9f70-fa9b1166f6cb/resource/0e15d04d-127c-457a-b999-20800c929927/download/municipality-population.csv"

pop <- read_csv(pop_url, col_select = c(Region, Year, Gender, Total), show_col_types = FALSE) %>%
  filter(Gender == "T", Year %in% c(2003, 2023, 2046), Region != 0) %>%
  select(-Gender) %>%
  pivot_wider(names_from = Year, values_from = Total) %>%
  mutate(
    change_23_03 = `2023` - `2003`,
    change_46_23 = `2046` - `2023`
  )

# Region codes are census division * 1000 + subdivision (e.g. Chilliwack 9020 -> CSD 5909020).
# Areas outside municipalities are reported as one "Unincorporated Areas" total per
# regional district (code CD * 1000 + 999), so those CSD polygons are merged to match.
csd_geogs <- census_subdivision() %>%
  st_intersection(bc_bound_hres()) %>%
  mutate(
    csd = as.numeric(CENSUS_SUBDIVISION_ID) - 5900000,
    Region = if_else(csd %in% pop$Region, csd, (csd %/% 1000) * 1000 + 999)
  ) %>%
  group_by(Region) %>%
  summarise()

# Every region in the data should land on the map
stopifnot(all(pop$Region %in% csd_geogs$Region))

pop_map <- csd_geogs %>%
  left_join(pop, by = "Region") %>%
  st_transform(crs = 4326)

# Map code ----
# Inset box around Metro Vancouver
inset_box <- c(xmin = -123.3, xmax = -122.7, ymin = 49, ymax = 49.3)

make_map <- function(change, breaks, labels, legend_title, file) {
  palette <- rev(viridisLite::viridis(length(labels), option = "D"))

  main_map <- ggplot(pop_map) +
    geom_sf(aes(fill = cut(.data[[change]], breaks = breaks, labels = labels, include.lowest = TRUE)),
            lwd = 0.2,
            colour = "black") +
    scale_fill_manual(values = palette, drop = FALSE, na.value = "gray") +
    theme_void() +
    theme(legend.position = "inside",
          legend.position.inside = c(0.25, 0.2),
          legend.title = element_text(face = "bold")) +
    annotate("rect",
             xmin = inset_box["xmin"], xmax = inset_box["xmax"],
             ymin = inset_box["ymin"], ymax = inset_box["ymax"],
             fill = NA, colour = "black", linewidth = 0.7) +
    labs(fill = legend_title)

  final_map <- ggdraw(main_map, xlim = c(.15, 1), ylim = c(0, 1)) +
    draw_plot({
      main_map +
        coord_sf(
          xlim = inset_box[c("xmin", "xmax")],
          ylim = inset_box[c("ymin", "ymax")],
          expand = FALSE
        ) +
        theme(legend.position = "none")
    },
    # The distance along a (0,1) x-axis to draw the left edge of the plot
    x = 0.64,
    # The distance along a (0,1) y-axis to draw the bottom edge of the plot
    y = 0.55,
    # The width and height of the plot expressed as proportion of the entire ggdraw object
    width = 0.4,
    height = 0.4)

  dir.create("maps", showWarnings = FALSE)
  ggsave(file.path("maps", file), final_map, bg = "white", width = 12, height = 8)
}

# Figure change_23_03 ----
make_map(
  "change_23_03",
  breaks = c(-Inf, -1000, -100, 0, 50, 100, 1000, 10000, 50000, 100000, Inf),
  labels = c("Less than -1000", "-1000 to -100", "-100 to 0",
             "0 to 50", "50 to 100", "100 to 1000",
             "1000 to 10,000", "10,000 to 50,000",
             "50,000 to 100,000", "More than 100,000"),
  legend_title = "Population change\n2003-2023",
  file = "change_23_03.png"
)

# Figure change_46_23 ----
make_map(
  "change_46_23",
  breaks = c(-Inf, 0, 25, 50, 100, 1000, 10000, 50000, 100000, Inf),
  labels = c("Less than 0", "0 to 25",
             "25 to 50", "50 to 100", "100 to 1000",
             "1000 to 10,000", "10,000 to 50,000",
             "50,000 to 100,000", "More than 100,000"),
  legend_title = "Projected change\n2023-2046",
  file = "change_46_23.png"
)
