# 03_relationship.R -- Question 3: weighted literacy rate by age band, women and men.
# Variant 2 = Sindh (prov_code 3), rural (urban_rural 1).
suppressPackageStartupMessages({library(ggplot2); library(dplyr); library(readr)})

f <- sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))
if (length(f) == 1) setwd(file.path(dirname(normalizePath(f)), ".."))
dir.create("figures", showWarnings = FALSE); dir.create("output", showWarnings = FALSE)

person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh     <- read_csv("data/pslm_hh_subset.csv",     show_col_types = FALSE) |>
  select(hhid, hhweight, prov_code, urban_rural)
d <- left_join(person, hh, by = "hhid") |> filter(prov_code == 3, urban_rural == 1)

lit <- d |> filter(age >= 10, age <= 64, !is.na(literate)) |>
  mutate(lo  = (age %/% 5) * 5,                       # band start: 10, 15, ..., 60
         mid = lo + 2,                                # band midpoint: 12, 17, ..., 62
         band = paste0(lo, "-", lo + 4),
         sex_lab = ifelse(sex == 1, "Men", "Women"))

# --- band table: n and weighted literacy rate (sum w*x / sum w) per sex -------
tab <- lit |> group_by(lo, mid, band, sex_lab) |>
  summarise(n = n(), rate = 100 * sum(hhweight * literate) / sum(hhweight), .groups = "drop") |>
  mutate(rate = round(rate, 1), thin = n < 30)

wide <- tab |> select(lo, band, sex_lab, n, rate) |>
  tidyr::pivot_wider(names_from = sex_lab, values_from = c(n, rate)) |>
  mutate(gap = round(rate_Men - rate_Women, 1)) |> arrange(lo)
write_csv(wide |> select(band, n_Women, rate_Women, n_Men, rate_Men, gap), "output/band_table_R.csv")
print(as.data.frame(wide))

big  <- wide |> slice_max(abs(gap), n = 1, with_ties = FALSE)
bmid <- big$lo + 2
cat(sprintf("\nWomen 15-19: %.1f  Men 15-19: %.1f\nWomen 55-59: %.1f  Men 55-59: %.1f\nLargest gap: %s (%.1f points)\n",
            wide$rate_Women[wide$band == "15-19"], wide$rate_Men[wide$band == "15-19"],
            wide$rate_Women[wide$band == "55-59"], wide$rate_Men[wide$band == "55-59"],
            big$band, big$gap))

# --- figure -------------------------------------------------------------------
cols <- c(Women = "#D55E00", Men = "#0072B2")
last <- tab |> filter(lo == 60)
yw <- big$rate_Women; ym <- big$rate_Men

ttl <- sprintf("In rural Sindh, women trail men in literacy at every age; the gap peaks at ages %s, at %.1f points",
               big$band, big$gap)
cap <- sprintf(paste0("Source: PSLM 2019-20 person file. Sample: persons aged 10-64 in rural Sindh with literate not missing ",
                      "(n = %s). Weighted by hhweight. Hollow markers: age band with fewer than 30 observations for that sex."),
               format(nrow(lit), big.mark = ","))
wrap <- function(x, n) paste(strwrap(x, n), collapse = "\n")

p <- ggplot(tab, aes(mid, rate, colour = sex_lab, group = sex_lab)) +
  annotate("segment", x = bmid, xend = bmid, y = yw, yend = ym, colour = "grey35", linewidth = 0.6) +
  annotate("text", x = bmid + 1, y = (yw + ym) / 2, hjust = 0, size = 3.5, colour = "grey20", lineheight = 0.95,
           label = sprintf("Largest gap:\n%.1f points\n(ages %s)", big$gap, big$band)) +
  geom_line(linewidth = 0.9) +
  geom_point(aes(fill = ifelse(thin, "white", sex_lab)), shape = 21, size = 3, stroke = 1.1) +
  scale_fill_manual(values = c(cols, white = "white"), guide = "none") +
  geom_text(data = last, aes(label = sex_lab), hjust = 0, nudge_x = 1.2, fontface = "bold", size = 4) +
  scale_colour_manual(values = cols, guide = "none") +
  scale_x_continuous(breaks = seq(12, 62, 5), labels = function(x) paste0(x - 2, "-", x + 2),
                     expand = expansion(mult = c(0.02, 0.03))) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20),
                     labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0, 0.02))) +
  coord_cartesian(xlim = c(10, 68), clip = "off") +
  labs(title = wrap(ttl, 80), caption = wrap(cap, 125),
       x = "Age band (years)", y = "Weighted literacy rate") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 12.5),
        plot.title.position = "plot", plot.caption.position = "plot",
        plot.caption = element_text(hjust = 0, size = 8.5, colour = "grey30"),
        panel.grid.minor = element_blank(), panel.grid.major.x = element_blank())

ggsave("figures/literacy_by_age.svg", p, width = 9, height = 5.6)
