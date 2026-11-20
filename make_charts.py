import pandas as pd, matplotlib, os
os.makedirs("images", exist_ok=True)
matplotlib.use("Agg"); import matplotlib.pyplot as plt
# Same cleaning steps as sql/02_data_cleaning.sql, done in pandas to cross-check the SQL result
raw = pd.read_csv("data/layoffs_raw.csv", keep_default_na=False).replace({"NULL": None})
d = raw[~raw.duplicated()].copy()                                   # 5 exact duplicates
d["company"] = d["company"].str.strip()
d.loc[d["industry"] == "", "industry"] = None
known = d.dropna(subset=["industry"]).groupby("company")["industry"].first()
d["industry"] = d["industry"].fillna(d["company"].map(known))       # fill from same company
d.loc[d["industry"].str.startswith("Crypto", na=False), "industry"] = "Crypto"
d["country"] = d["country"].str.rstrip(".")
d["location"] = d["location"].replace({"Dusseldorf": "Düsseldorf", "Malmo": "Malmö"})
d["date"] = pd.to_datetime(d["date"], format="%m/%d/%Y")
for c in ["total_laid_off", "percentage_laid_off", "funds_raised_millions"]:
    d[c] = pd.to_numeric(d[c])
d = d[~(d["total_laid_off"].isna() & d["percentage_laid_off"].isna())]
print("clean rows:", len(d))                                         # 1995
d.to_csv("data/layoffs_clean.csv", index=False, date_format="%Y-%m-%d")
plt.rcParams.update({"font.size": 11, "axes.spines.top": False, "axes.spines.right": False})
C = "#2F5597"

m = d.dropna(subset=["date"]).groupby(d.date.dt.to_period("M")).total_laid_off.sum()
m.index = m.index.to_timestamp()
fig, ax = plt.subplots(figsize=(10, 4.5))
ax.bar(m.index, m.values, width=20, color=C)
ax.set_title("Layoffs per month (Mar 2020 – Mar 2023)", loc="left", fontweight="bold")
ax.set_ylabel("People laid off")
pk = m.idxmax(); ax.annotate(f"Jan 2023: {int(m.max()):,}", (pk, m.max()), xytext=(-150, -10), textcoords="offset points", arrowprops=dict(arrowstyle="->"))
fig.tight_layout(); fig.savefig("images/01_monthly_layoffs.png", dpi=100)

t = d.groupby("company").total_laid_off.sum().nlargest(10).sort_values()
fig, ax = plt.subplots(figsize=(9, 4.8))
ax.barh(t.index, t.values, color=C)
for i, v in enumerate(t.values): ax.text(v + 150, i, f"{int(v):,}", va="center", fontsize=10)
ax.set_title("Top 10 companies by total layoffs", loc="left", fontweight="bold")
fig.tight_layout(); fig.savefig("images/02_top_companies.png", dpi=100)

i = d.groupby("industry").total_laid_off.sum().nlargest(10).sort_values()
fig, ax = plt.subplots(figsize=(9, 4.8))
ax.barh(i.index, i.values, color=C)
for k, v in enumerate(i.values): ax.text(v + 300, k, f"{int(v):,}", va="center", fontsize=10)
ax.set_title("Top 10 industries by total layoffs", loc="left", fontweight="bold")
fig.tight_layout(); fig.savefig("images/03_top_industries.png", dpi=100)
