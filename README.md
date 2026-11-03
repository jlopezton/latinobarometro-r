# latinobarometro

An R package to download Latinobarometro survey waves (1995–2024) from the
Latinobarometro Corporation archive, harmonize variable names across waves
using the official time-series crosswalk, and build population-scaled weights
for pooled regional analysis.

This is the R counterpart of the [`latinobarometro` Stata
command](https://github.com/jlopezton/latinobarometro-stata). Same pipeline,
same crosswalk, idiomatic R interface: functions return a data frame instead of
replacing the dataset in memory.

## Installation

```r
# Development version
# install.packages("remotes")
remotes::install_github("jlopezton/latinobarometro-r")
```

`WDI` is only needed for population weights:

```r
install.packages("WDI")
```

## Usage

```r
library(latinobarometro)

# Keep downloads between sessions (asks once, then remembers)
lb_cache_dir(persist = TRUE)

# One wave, variable names harmonized across waves
d <- lb_load(2023)

# Raw names, exactly as published
d <- lb_load(2023, harmonize = FALSE)

# Add population-scaled weights for pooled regional estimates
d <- lb_load(2023, add_population = TRUE)

# Stack several waves into a panel
p <- lb_pool(c(2018, 2020, 2023), keep = c("X_001", "X_020", "P12ST_A"))
```

| Function | Does |
|---|---|
| `lb_load()` | Download, read and harmonize one wave — the usual entry point |
| `lb_pool()` | Load several waves and stack them into a panel |
| `lb_download()` | Fetch and unzip a wave into the cache |
| `lb_read()` | Read a cached wave |
| `lb_harmonize()` | Apply the crosswalk to already-loaded data |
| `lb_add_population()` | Merge World Bank population and build `wt_lac` |
| `lb_crosswalk()` | The time-series crosswalk as a data frame |
| `lb_years()`, `lb_files()` | Which waves and files exist |
| `lb_cache_dir()`, `lb_clear_cache()` | Manage the download cache |
| `lb_refresh_urls()` | Check the built-in file table against the live site |

## Which file gets downloaded

Latinobarometro publishes each wave in several formats, and the filenames
follow no consistent pattern. Native R files exist only for some waves:

| Waves | R file | Fallback used |
|---|---|---|
| 1995–2011 | none published | Stata `.dta` via `haven` |
| 2013, 2015–2017 | `-r.zip` (`.RData` or `.rds` inside) | — |
| 2018 | `-eng-r-` / `-esp-r-` | — |
| 2020, 2023 | separate `-rdata-` and `-rds-` archives | — |
| 2024 | none published | Stata `.dta` via `haven` |

`format = "auto"` (the default) is a chain, not a single guess: `.rds` →
`.RData` → `.dta` → `.sav`, taking the first that both exists and parses. The
SPSS step is not redundant — **the 2024 Stata file is written in a `.dta`
format newer than `haven` supports**, so that wave is only reachable through its
SPSS twin. Pin `format = "dta"` (or any other) to fail loudly instead of
falling back.

Two defects in the published files are handled automatically:

- **Malformed value-label tables.** The 2024 English `.dta` strands one label
  past the declared end of its text block. Stata tolerates this; `haven`
  rejects the entire file with a misleading "unsupported features" error. The
  fallback chain moves on to the SPSS file, which is why 2024 arrives as
  `.sav`. Check `attr(d, "lb_format")` if you need to know which file you got.
- **Undeclared text encoding.** Files predating Stata 14 record no encoding.
  This archive mixes latin1 (older waves) and UTF-8 (2024), so the package
  tries UTF-8 first — it is self-validating, whereas `haven`'s windows-1252
  default decodes UTF-8 files into mojibake without ever raising an error.

Because column types differ between sources — `.dta` and `.sav` give
`haven_labelled` columns, native R files usually give plain numerics or factors
— `lb_pool()` defaults to `format = "dta"` so every wave in a panel is read the
same way.

## Caching

Downloads are cached so each wave is fetched at most once. The default cache is
session-scoped; `lb_cache_dir(persist = TRUE)` moves it to
`tools::R_user_dir("latinobarometro", "cache")` so waves survive across
sessions. `force = TRUE` re-downloads.

## Weights

`wt_lac` rescales each national sample so that countries enter pooled regional
estimates in proportion to their population rather than their sample size. It
is a weight for **point estimates**, not a frequency weight and not a
description of the sampling design. For standard errors, declare the actual
national design with `survey::svydesign()` using the design variables published
with the wave.

## Data terms

This package downloads data at run time and redistributes nothing.
Latinobarometro's terms of use prohibit republishing their data, which is why
there is deliberately no fallback mirror: if the archive is unreachable the
package fails rather than serving a copy from elsewhere. You remain responsible
for complying with those terms and for citing the waves you use:

> Latinobarómetro Study 2023. Corporación Latinobarómetro: 2023 Wave –
> Aggregated Version. Madrid: JD Systems Institute.

## Notes for users of the Stata package

Two things differ.

The elaborate variable- and value-label-name repair in the Stata version has no
counterpart here. Periods are legal in R names, and `haven` attaches value
labels to each column as an attribute rather than through shared, named label
sets — so the invalid-label-name problem that broke the 2016 and 2017 waves in
Stata cannot arise. `lb_clean_names()` is available if you want Stata-style
names anyway.

The Stata version reads `.dta` for every wave. This one prefers the native R
file where Latinobarometro publishes one. Pass `format = "dta"` for exact
parity.

## License

MIT. The survey data themselves are not included and are governed by
Latinobarometro's terms, not by this code license.

## Credits

Originally developed from Germán Reyes' (World Bank–Cornell) internal
repository-pulling command.
