"""04_python_check.py -- Question 5: recompute the Q3 band table and redraw the figure in Python.
Variant 2 = Sindh (prov_code 3), rural (urban_rural 1).
Run from anywhere:  python scripts/04_python_check.py
"""
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
os.chdir(root)
os.makedirs("figures", exist_ok=True)
os.makedirs("output", exist_ok=True)

person = pd.read_csv("data/pslm_person_subset.csv")
hh = pd.read_csv("data/pslm_hh_subset.csv")[["hhid", "hhweight", "prov_code", "urban_rural"]]
d = person.merge(hh, on="hhid", how="left")
d = d[(d.prov_code == 3) & (d.urban_rural == 1)]

lit = d[d.age.between(10, 64) & d.literate.notna()].copy()
lit["lo"] = (lit.age // 5) * 5
lit["sex_lab"] = np.where(lit.sex == 1, "Men", "Women")

# weighted literacy rate = sum(w*x)/sum(w), in percent
def wrate(g):
    return pd.Series({"n": len(g),
                      "rate": 100 * (g.hhweight * g.literate).sum() / g.hhweight.sum()})

tab = lit.groupby(["lo", "sex_lab"]).apply(wrate, include_groups=False).reset_index()
tab["rate"] = tab["rate"].round(1)
tab["n"] = tab["n"].astype(int)
tab["mid"] = tab.lo + 2
tab["thin"] = tab.n < 30

wide = tab.pivot(index="lo", columns="sex_lab", values=["n", "rate"])
wide.columns = [f"{a}_{b}" for a, b in wide.columns]
wide = wide.reset_index()
wide[["n_Women", "n_Men"]] = wide[["n_Women", "n_Men"]].astype(int)
wide["band"] = wide.lo.astype(str) + "-" + (wide.lo + 4).astype(str)
wide["gap"] = (wide.rate_Men - wide.rate_Women).round(1)
out = wide[["band", "n_Women", "rate_Women", "n_Men", "rate_Men", "gap"]]
out.to_csv("output/band_table_py.csv", index=False)

# --- compare with the R table to one decimal place ---------------------------
r = pd.read_csv("output/band_table_R.csv")
same = (r.band.values == out.band.values).all() and \
       np.allclose(r[["rate_Women", "rate_Men", "gap"]].values, out[["rate_Women", "rate_Men", "gap"]].values, atol=0.049) and \
       (r[["n_Women", "n_Men"]].values == out[["n_Women", "n_Men"]].values).all()
print(out.to_string(index=False))
print("\nPython women 15-19:", float(out.loc[out.band == "15-19", "rate_Women"].iloc[0]))
print("R      women 15-19:", float(r.loc[r.band == "15-19", "rate_Women"].iloc[0]))
print("Tables agree with R to one decimal:", bool(same))

# --- figure -------------------------------------------------------------------
cols = {"Women": "#D55E00", "Men": "#0072B2"}
big = wide.loc[wide.gap.abs().idxmax()]
bmid = big.lo + 2
fig, ax = plt.subplots(figsize=(9, 5.6))
for sex in ["Women", "Men"]:
    t = tab[tab.sex_lab == sex].sort_values("mid")
    ax.plot(t.mid, t.rate, color=cols[sex], lw=2, zorder=2)
    ax.scatter(t.mid, t.rate, s=60, zorder=3, edgecolors=cols[sex], linewidths=1.8,
               facecolors=["white" if th else cols[sex] for th in t.thin])
    ax.text(t.mid.iloc[-1] + 1.2, t.rate.iloc[-1], sex, color=cols[sex], fontweight="bold",
            va="center", fontsize=11)
ax.plot([bmid, bmid], [big.rate_Women, big.rate_Men], color="0.35", lw=1.5, zorder=1)
ax.text(bmid + 1, (big.rate_Women + big.rate_Men) / 2,
        f"Largest gap:\n{big.gap:.1f} points\n(ages {big.band})", va="center", fontsize=9.5, color="0.15")
ax.set_xlim(10, 68); ax.set_ylim(0, 100)
ax.set_xticks(range(12, 63, 5))
ax.set_xticklabels([f"{x-2}-{x+2}" for x in range(12, 63, 5)])
ax.set_yticks(range(0, 101, 20)); ax.set_yticklabels([f"{y}%" for y in range(0, 101, 20)])
ax.set_xlabel("Age band (years)"); ax.set_ylabel("Weighted literacy rate")
ax.grid(axis="y", color="0.9"); ax.set_axisbelow(True)
for s in ["top", "right", "left", "bottom"]:
    ax.spines[s].set_visible(False)
ax.tick_params(length=0)
fig.suptitle(f"In rural Sindh, women trail men in literacy at every age; the gap peaks at ages\n{big.band}, at {big.gap:.1f} points",
             x=0.01, ha="left", fontweight="bold", fontsize=12)
fig.text(0.01, 0.01,
         f"Source: PSLM 2019-20 person file. Sample: persons aged 10-64 in rural Sindh with literate not missing (n = {len(lit):,}).\n"
         "Weighted by hhweight. Hollow markers: age band with fewer than 30 observations for that sex.",
         fontsize=8, color="0.3", ha="left", va="bottom")
fig.subplots_adjust(top=0.86, bottom=0.2, left=0.08, right=0.97)
fig.savefig("figures/literacy_by_age_python.svg")
print("saved figures/literacy_by_age_python.svg")
