# 01_default.R -- Question 4: R's default scatterplot, nothing added.
# Variant 2 = Sindh (prov_code 3), rural (urban_rural 1).
# Run from anywhere:  Rscript scripts/01_default.R
suppressPackageStartupMessages({library(ggplot2); library(dplyr); library(readr)})

# --- move to the repository root so relative paths work ---------------------
f <- sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))
if (length(f) == 1) setwd(file.path(dirname(normalizePath(f)), ".."))
dir.create("figures", showWarnings = FALSE)

# --- read local copies and attach hhweight, prov_code, urban_rural by hhid ---
person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh     <- read_csv("data/pslm_hh_subset.csv",     show_col_types = FALSE) |>
  select(hhid, hhweight, prov_code, urban_rural)
d <- left_join(person, hh, by = "hhid") |>
  filter(prov_code == 3, urban_rural == 1)          # variant 2: Sindh rural

# --- literacy sample: aged 10-64, literate not missing -----------------------
lit <- d |> filter(age >= 10, age <= 64, !is.na(literate))

# --- the default figure: exactly this and nothing else -----------------------
p <- ggplot(lit, aes(age, literate)) + geom_point()
ggsave("figures/default.svg", p)
cat("Default figure saved. Persons plotted:", nrow(lit), "\n")
