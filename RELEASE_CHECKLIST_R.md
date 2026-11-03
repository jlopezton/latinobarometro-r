# latinobarometro (R) — release checklist

Everything below needs an actual R installation; none of it has been run yet.

## 1. Generate documentation

`man/*.Rd` is not in the repo — the roxygen comments are, so generate it:

```r
install.packages(c("devtools", "roxygen2"))
devtools::document()      # writes man/ and regenerates NAMESPACE
```

`NAMESPACE` is currently hand-written to match what roxygen will produce.
If `document()` changes it, roxygen wins.

## 2. Offline tests first

```r
devtools::test(filter = "manifest|harmonize|population|load")
```

These need no network. They cover the parts most likely to regress: the
candidate-spelling rule in the crosswalk match, the 2016/2017 hyphenless stem
(which was a live bug in the Stata version), the population rescaling
arithmetic, and stacking waves whose value labels disagree.

## 3. Live tests

```r
devtools::test(filter = "network")
```

`test-network.R` HEAD-requests **every** URL in the built-in table. This is the
R equivalent of the Stata year→URL verification, and it is the check to re-run
before every release — Latinobarometro re-releases waves under new filenames
(`-v1-0`, `-v20190303`, `-v20250817`) without notice.

Also confirm end to end:

- [ ] 2023 loads from `.rds` and harmonizes
- [ ] 2024 falls back to `.dta` (no R file is published for 2024)
- [ ] 2013 loads — its `-r.zip` is not self-describing; note whether it holds
      `.RData` or `.rds` and record it in `R/manifest.R`
- [ ] 2016 and 2017 load — these were the waves that broke Stata
- [ ] `lb_pool()` stacks two waves without a labelled-class error

## 4. Verify parity with the Stata package

The crosswalk logic was validated in Stata against a hand-built 2020 rename
list: 5,809 / 5,809 exact matches. Reproduce that here so the two packages
provably agree:

```r
d <- lb_load(2020, format = "dta", harmonize = TRUE)
# compare names(d) against the Stata output for the same wave
```

Any divergence is almost certainly in `lb_name_candidates()`.

## 5. R CMD check

```r
devtools::check(args = c("--as-cran"))
```

Then the other platforms:

```r
devtools::check_win_devel()
devtools::check_mac_release()
rhub::rhub_check()
```

Target: 0 errors, 0 warnings, 0 notes other than the new-submission note.

## 6. CRAN name availability

`latinobarometro` did not appear in a CRAN search on 13 August 2026, but
confirm properly before submitting:

```r
available::available("latinobarometro")
```

This also checks Bioconductor and, usefully, whether the name means something
unfortunate in another language.

## 7. Submission

- [ ] Bump `Version:` in DESCRIPTION and add a `NEWS.md` entry
- [ ] Fill in `cran-comments.md` with real check output
- [ ] `devtools::release()`
- [ ] Expect a reviewer question about run-time downloads — the answer is in
      `cran-comments.md`: nothing is redistributed, nothing is written outside
      `tempdir()` without consent

## Findings from the first live run (13 Aug 2026)

All 48 manifest URLs were live; the crosswalk, 2023 and `lb_refresh_urls()`
all passed. Two reader failures, both now handled:

- **2024 `.dta` would not parse at all.** The error, "Invalid file, or file has
  unsupported features", is misleading: the file is dta format 115 (Stata 12),
  which ReadStat supports fine. Diagnosed by bisection against `pyreadstat`,
  which wraps the same C library:

  > The value-label table for **S5** declares six entries with text offsets
  > 0, 27, 78, 114, 156, **167** — while declaring the text block to be exactly
  > **167 bytes** long. The sixth label ("No answer", for the extended missing
  > `.b`) is physically present in the file immediately after the declared end;
  > whatever wrote the file never grew `txtlen` to cover it. Stata uses the
  > table's total length and reads it. ReadStat bounds-checks against `txtlen`,
  > finds an offset one past the end, and aborts **the entire 13 MB file**.

  **Resolution: the wave falls back to its SPSS file.** A byte-level repair was
  built and verified — recomputing `txtlen` from the table's declared length
  (`len - 8 - 8n`, the quantity Stata trusts) made the wave read as
  19,214 × 332 with all 316 label sets and the correct "No answer" label — but
  it was dropped deliberately in favour of the simpler fallback. Roughly 120
  lines of hand-rolled binary `.dta` parsing is a poor thing to maintain and to
  defend at CRAN review, for one wave.

  Consequences to keep in mind:

  - 2024 English data now comes from a **different source file** than the Stata
    package reads, so the 5,809/5,809 crosswalk parity check does not cover
    that wave. Worth spot-checking `lb_load(2024)` against the Stata output.
  - `attr(d, "lb_format")` records which file was actually used. Anyone needing
    strict Stata parity should pin `format = "dta"` and will get a clear error
    for 2024.
  - The Spanish 2024 file has no such defect, and reads fine.

  Worth reporting upstream to Latinobarometro, and arguably to ReadStat as a
  tolerance issue. If it is ever fixed at source, nothing here needs changing —
  the chain will simply stop on `.dta` again.
- **2020 `.dta` failed on text encoding**, and the fix uncovered a worse,
  silent problem. Files written before Stata 14 declare no encoding and haven
  assumes windows-1252. That is wrong in *both* directions here: older waves
  really are latin1 and error out, while the 2024 files are UTF-8 and do **not**
  error — every byte is valid windows-1252, so the labels come back as mojibake
  (`Itâ€™s enough` instead of `It's enough`). Silent corruption is worse than a
  crash, and the original "try the default first" chain would have shipped it.

  Now UTF-8 is tried first, then latin1, then windows-1252. UTF-8 is
  self-validating, so a latin1 file rejects it rather than decoding wrongly,
  whereas the reverse order mangles the UTF-8 files silently. Re-run the full
  network suite: this likely affected every pre-2013 wave.

## Status: 130 tests passing (13 Aug 2026)

Offline and network suites both green after the fixes above.

One piece of cosmetic noise remains: reading some waves prints
`Invalid date string (length=9): 17 031 25`. This comes from ReadStat's C code,
not from R, so it cannot be caught by `suppressWarnings()` or redirected from
within the package. It is a malformed date in the published file (most likely a
header timestamp), it is harmless, and nothing downstream is affected. Mention
it in the README if users start asking.

## All-wave smoke test (13 Aug 2026)

Every wave loads and harmonizes. Reference figures — compare against these
after any change to the reader or the manifest, and after any upstream
re-release:

| Wave | Rows | Format | | Wave | Rows | Format |
|---|---|---|---|---|---|---|
| 1995 | 9,069 | dta | | 2008 | 22,675 | dta |
| 1996 | 21,200 | dta | | 2009 | 22,690 | dta |
| 1997 | 20,243 | dta | | 2010 | 22,687 | dta |
| 1998 | 20,331 | dta | | 2011 | 20,204 | dta (latin1) |
| 2000 | 18,038 | dta | | 2013 | 22,663 | r |
| 2001 | 20,631 | dta | | 2015 | 20,250 | r |
| 2002 | 21,006 | dta | | 2016 | 20,204 | r |
| 2003 | 21,133 | dta | | 2017 | 20,200 | r |
| 2004 | 22,096 | dta | | 2018 | 20,204 | r |
| 2005 | 20,222 | dta | | 2020 | 20,204 | rds |
| 2006 | 22,708 | dta | | 2023 | 19,205 | rds |
| 2007 | 22,694 | dta | | 2024 | 19,214 | sav |

Notes:

- 1995's small N is expected: that wave covered 8 countries, not 18.
- 2024's 19,214 read via SPSS matches the row count in the Stata file's own
  header, so the fallback is not returning different data.
- **Resolved.** 2011, 2016, 2018 and 2020 all report exactly 20,204 rows, from
  three different formats. All four carry 18 countries, so this is the fixed
  national quota design, not a cache collision.
- **Resolved.** Accented labels verified across 2000, 2005, 2010 and 2011:
  `Córdoba`, `Santa Fé`, `Patagónica`, `República Dominicana` all decode
  correctly, with no mojibake signature.

  Worth recording *why* that matters. Those waves split across both branches of
  the chain: 2000, 2005 and 2010 decode as **UTF-8**, while 2011 falls through
  to **latin1**. The archive mixes the two, sometimes between adjacent waves.
  An earlier version of this package tried latin1 before UTF-8 — and because
  latin1 accepts any byte sequence, that order would have silently rendered
  every UTF-8 wave as `CÃ³rdoba` without raising a single error. Do not
  reorder the encoding chain in `lb_read_labelled()`; UTF-8 must stay first
  precisely because it is the only one of the three that can fail.

## Open items

- **No vignette yet.** Not required, but CRAN reviewers like one. It would have
  to use `eval = FALSE` or be pre-built, since every example needs the network.
- **`-r.zip` contents unverified** for 2013 and 2015–2018. `lb_read_file()`
  dispatches on the real extension found on disk, so all three possibilities
  (`.rds`, `.RData`, `.rda`) are handled, but nobody has actually opened one.
- **Column-type drift between formats.** A wave read from `.rds` and the same
  wave read from `.dta` will not have identical column types. `lb_pool()`
  defaults to `format = "dta"` to sidestep this; worth documenting in a
  vignette once one exists.
- **1996–1998 and 2001–2010 have no `sav` entry in the manifest**, so those
  waves have no fallback if their `.dta` turns out to be unreadable the way
  2024's was. Their `.sav` URLs almost certainly follow the
  `latinobarometro-<year>-sav.zip` pattern confirmed for 1995, 2000 and 2011,
  but that was not verified, so nothing was guessed into the table. Add them
  only if the full network run shows one of those waves failing.
