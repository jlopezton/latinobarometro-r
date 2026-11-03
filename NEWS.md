# latinobarometro 0.1.0

First release. R counterpart of the `latinobarometro` Stata command.

* `lb_load()` downloads, reads and harmonizes a single wave; `lb_pool()` stacks
  several into a panel.
* `lb_download()`, `lb_read()`, `lb_harmonize()` and `lb_add_population()` are
  exported separately so each step can be run on its own.
* Built-in table of published data files for all 24 waves, verified against the
  live archive on 13 August 2026. `lb_refresh_urls()` checks it for drift.
* Native R files (`.rds`, `.RData`) are preferred where Latinobarometro
  publishes them (2013–2023); waves 1995–2011 and 2024 fall back to the Stata
  `.dta` archive read through `haven`.
* Downloads are cached; the cache is session-scoped until
  `lb_cache_dir(persist = TRUE)` is called.
* `format = "auto"` is a fallback chain rather than a single guess, taking the
  first published file that both exists and parses. The 2024 Stata file is
  malformed in a way Stata tolerates and `haven` rejects, so that wave resolves
  to its SPSS twin; `attr(d, "lb_format")` records which file was used.
* Text encoding is resolved by trying UTF-8 before latin1, because this archive
  mixes the two and `haven`'s windows-1252 default silently turns UTF-8 labels
  into mojibake rather than failing.
