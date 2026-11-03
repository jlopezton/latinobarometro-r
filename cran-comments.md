# cran-comments.md

## Test environments

- [ ] local macOS, R release
- [ ] win-builder (devel and release) — `devtools::check_win_devel()`
- [ ] macOS builder — `devtools::check_mac_release()`
- [ ] R-hub: linux, windows, macos — `rhub::rhub_check()`

## R CMD check results

_(paste output here — target is 0 errors, 0 warnings, 0 notes besides the
new-submission note)_

## Notes for the CRAN reviewers

**External data.** The package downloads survey files at run time from
<https://www.latinobarometro.org>. Nothing is redistributed with the package.
Latinobarometro's terms of use prohibit republishing their data, which is why
there is no fallback mirror; a failed download raises an informative error
rather than silently trying another source.

**Writes to disk.** No file is written outside `tempdir()` unless the user
explicitly calls `lb_cache_dir(persist = TRUE)` or `lb_cache_dir(path = ...)`.
The persistent location is `tools::R_user_dir("latinobarometro", "cache")`.
The default cache is a subdirectory of `tempdir()` and a message tells the user
how to opt in to persistence.

**Examples and tests.** Every example that touches the network is wrapped in
`\donttest{}` and additionally in `try()`. Network tests are in
`tests/testthat/test-network.R` and begin with `skip_on_cran()` plus a
`curl::has_internet()` guard. The remaining tests are fully offline.

**Suggested package.** `WDI` is used only by `lb_add_population()` and is
guarded with `requireNamespace()`, which raises an install message if absent.
