library(dplyr)
library(sf)
library(bcmaps)
library(ggplot2)
library(cowplot)

# Data ----
# BC Sub-Provincial Population Estimates and Projections, Municipalities (Census Subdivisions)
# Open Government Licence - British Columbia
pop_url <- "https://catalogue.data.gov.bc.ca/dataset/86839277-986a-4a29-9f70-fa9b1166f6cb/resource/0e15d04d-127c-457a-b999-20800c929927/download/municipality-population.csv"

pop <- read.csv(pop_url) %>%
  filter(Gender == "T", Region != 0) %>%
  group_by(Region) %>%
  summarise(
    # Percent change, so small towns and big cities read on the same scale
    change_23_03 = 100 * (Total[Year == 2023] / Total[Year == 2003] - 1),
    change_46_23 = 100 * (Total[Year == 2046] / Total[Year == 2023] - 1)
  )

# Region codes are census division * 1000 + subdivision (e.g. Chilliwack 9020 -> CSD 5909020).
# Areas outside municipalities are reported as one "Unincorporated Areas" total per
# regional district (code CD * 1000 + 999), so those CSD polygons are merged to match.
csd_geogs <- census_subdivision() %>%
  st_set_agr("constant") %>%
  st_intersection(st_geometry(bc_bound_hres())) %>%
  mutate(
    csd = as.numeric(CENSUS_SUBDIVISION_ID) - 5900000,
    Region = if_else(csd %in% pop$Region, csd, (csd %/% 1000) * 1000 + 999)
  ) %>%
  group_by(Region) %>%
  summarise()

stopifnot(all(pop$Region %in% csd_geogs$Region))

pop_map <- csd_geogs %>%
  left_join(pop, by = "Region") %>%
  st_transform(crs = 4326)

# Map code ----
# Inset box around Metro Vancouver
inset_box <- c(xmin = -123.3, xmax = -122.7, ymin = 49, ymax = 49.3)

make_map <- function(change, legend_title, title, file) {
  main_map <- ggplot(pop_map) +
    geom_sf(aes(fill = cut(.data[[change]], breaks = breaks, labels = labels)),
            lwd = 0.2,
            colour = "black") +
    scale_fill_manual(values = palette, drop = FALSE) +
    theme_void() +
    theme(legend.position = "inside",
          legend.position.inside = c(0.25, 0.2),
          legend.title = element_text(face = "bold")) +
    annotate("rect",
             xmin = inset_box["xmin"], xmax = inset_box["xmax"],
             ymin = inset_box["ymin"], ymax = inset_box["ymax"],
             fill = NA, colour = "black", linewidth = 0.7) +
    labs(fill = legend_title)

  inset <- main_map +
    coord_sf(xlim = inset_box[c("xmin", "xmax")], ylim = inset_box[c("ymin", "ymax")], expand = FALSE) +
    theme(legend.position = "none")

  final_map <- ggdraw(main_map, xlim = c(.15, 1), ylim = c(0, 1.08)) +
    draw_plot(inset, x = 0.64, y = 0.55, width = 0.4, height = 0.4) +
    draw_label(title, x = 0.17, y = 1.04, hjust = 0, fontface = "bold", size = 18)

  ggsave(file.path("maps", file), final_map, bg = "white", width = 12, height = 8.6)
}

# Figures ----
# Same bins on both maps so the colours mean the same thing
breaks <- c(-Inf, -20, -10, 0, 10, 25, 50, Inf)
labels <- c("Less than -20%", "-20% to -10%", "-10% to 0%",
            "0% to 10%", "10% to 25%", "25% to 50%", "More than 50%")
# BrBG has 4 browns and 4 teals; dropping the darkest brown leaves 3 for the 3 loss bins
palette <- RColorBrewer::brewer.pal(8, "BrBG")[-1]

grew <- sum(pop$change_23_03 > 0)
shrink <- sum(pop$change_46_23 < 0)

make_map(
  "change_23_03",
  legend_title = "Population change\n2003-2023",
  title = sprintf("%d of %d areas grew between 2003 and 2023", grew, nrow(pop)),
  file = "change_23_03.png"
)

make_map(
  "change_46_23",
  legend_title = "Projected change\n2023-2046",
  title = sprintf("%d of %d areas are projected to shrink by 2046", shrink, nrow(pop)),
  file = "change_46_23.png"
)
