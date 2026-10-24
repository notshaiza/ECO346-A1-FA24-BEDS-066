# 02_distribution.R -- Question 2: weighted histogram of annual education spending.
# Variant 2 = Sindh (prov_code 3), rural (urban_rural 1).
suppressPackageStartupMessages({library(ggplot2); library(dplyr); library(readr)})

f <- sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))
if (length(f) == 1) setwd(file.path(dirname(normalizePath(f)), ".."))
dir.create("figures", showWarnings = FALSE); dir.create("output", showWarnings = FALSE)

# weighted p-th quantile: smallest x whose cumulative weight share reaches p
wquant <- function(x, w, p) {
  o <- order(x); x <- x[o]; cw <- cumsum(w[o]) / sum(w)
  x[which(cw >= p - 1e-12)[1]]
}

person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh     <- read_csv("data/pslm_hh_subset.csv",     show_col_types = FALSE) |>
  select(hhid, hhweight, prov_code, urban_rural)
d <- left_join(person, hh, by = "hhid") |> filter(prov_code == 3, urban_rural == 1)

# students: ed_total > 0
s <- d |> filter(!is.na(ed_total), ed_total > 0) |> mutate(lx = log10(ed_total))

# --- statistics (all students) -----------------------------------------------
n_students <- nrow(s)
w_med   <- wquant(s$ed_total, s$hhweight, 0.5)
u_med   <- median(s$ed_total)
w_p10   <- wquant(s$ed_total, s$hhweight, 0.1)
w_p90   <- wquant(s$ed_total, s$hhweight, 0.9)
ratio   <- w_p90 / w_p10

# --- histogram data: bins 0.1 wide in log10 units, 2.0 to 6.0 -----------------
inr   <- s |> filter(lx >= 2, lx <= 6)
n_exc <- n_students - nrow(inr)
inr   <- inr |> mutate(bin = pmin(floor((lx - 2) / 0.1 + 1e-9) + 1, 40))
h <- inr |> group_by(bin) |> summarise(w = sum(hhweight), .groups = "drop") |>
  right_join(tibble(bin = 1:40), by = "bin") |> mutate(w = coalesce(w, 0)) |>
  arrange(bin) |>
  mutate(mid = 2 + (bin - 0.5) * 0.1,
         dens = w / sum(w) / 0.1)            # density per log10 unit

rs <- function(x) paste0("Rs ", format(round(x), big.mark = ",", trim = TRUE))

# --- sentences for the title and caption --------------------------------------
ttl <- sprintf("Half of students in rural Sindh cost households under %s a year, but one in ten costs %s or more",
               rs(w_med), rs(w_p90))
cap <- sprintf(paste0("Source: PSLM 2019-20 person file. Sample: students (ed_total > 0) in rural Sindh, n = %s. ",
                      "Weighted by hhweight. %d student(s) outside Rs 100-1,000,000 excluded from the bars ",
                      "(statistics use all students)."),
               format(n_students, big.mark = ","), n_exc)

wrap <- function(x, n) paste(strwrap(x, n), collapse = "\n")
ttl <- wrap(ttl, 75); cap <- wrap(cap, 125)

p <- ggplot(h, aes(mid, dens)) +
  geom_col(width = 0.1, fill = "#4C78A8", colour = "white", linewidth = 0.2) +
  geom_vline(xintercept = log10(c(w_med, w_p90)), linetype = "dashed", colour = "#222222") +
  annotate("text", x = log10(w_med) - 0.04, y = max(h$dens) * 1.14, hjust = 1, size = 3.6,
           label = paste0("Weighted median\n", rs(w_med))) +
  annotate("text", x = log10(w_p90) + 0.04, y = max(h$dens) * 1.14, hjust = 0, size = 3.6,
           label = paste0("Weighted 90th percentile\n", rs(w_p90))) +
  scale_x_continuous(breaks = 2:6,
                     labels = c("Rs 100", "Rs 1,000", "Rs 10,000", "Rs 100,000", "Rs 1,000,000"),
                     expand = expansion(mult = 0.01)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.04))) +
  coord_cartesian(xlim = c(1.9, 6.15)) +
  labs(title = ttl, caption = cap,
       x = "Annual education spending per student (log scale)",
       y = "Density per log10 unit") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 12.5),
        plot.title.position = "plot", plot.caption.position = "plot",
        plot.caption = element_text(hjust = 0, size = 8.5, colour = "grey30"),
        panel.grid.minor = element_blank(), panel.grid.major.x = element_blank())

ggsave("figures/distribution.svg", p, width = 9, height = 5.6)

res <- c(
  sprintf("students (ed_total > 0): %d", n_students),
  sprintf("weighted median: %.0f", w_med),
  sprintf("unweighted median: %.0f", u_med),
  sprintf("weighted p10: %.0f", w_p10),
  sprintf("weighted p90: %.0f", w_p90),
  sprintf("p90/p10 ratio: %.2f", ratio),
  sprintf("excluded (outside 2.0-6.0 log10): %d", n_exc))
writeLines(res, "output/q2_numbers_R.txt"); cat(res, sep = "\n")
