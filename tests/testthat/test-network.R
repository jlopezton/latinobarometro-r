# Live tests. Skipped on CRAN and whenever the machine is offline, per CRAN
# policy on tests that depend on external resources. Run them locally before
# a release with: devtools::test(filter = "network")

skip_if_offline_lb <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("curl")
  testthat::skip_if_not(curl::has_internet(), "No internet connection")
}

test_that("every manifest URL is still live", {
  skip_if_offline_lb()
  # Deliberately covers all waves: a re-release under a new filename is the
  # single most likely cause of a user-facing failure.
  tab <- lb_files()
  bad <- character(0)
  for (i in seq_len(nrow(tab))) {
    h <- tryCatch(curl::curl_fetch_memory(tab$url[i],
                    handle = curl::new_handle(nobody = TRUE, followlocation = TRUE)),
                  error = function(e) NULL)
    ok <- !is.null(h) && h$status_code == 200L &&
      !grepl("text/html", h$type %||% "", fixed = TRUE)
    if (!ok) bad <- c(bad, tab$url[i])
  }
  expect_equal(bad, character(0),
               info = paste("Dead or non-file URLs:", paste(bad, collapse = "\n")))
})

test_that("the crosswalk downloads and has the expected shape", {
  skip_if_offline_lb()
  lb_cache_dir(file.path(tempdir(), "lb_net_test"))

  cw <- lb_crosswalk(quiet = TRUE)
  expect_s3_class(cw, "data.frame")
  expect_true(all(c("variable", "title_en", "LAT2020", "LAT2024") %in% names(cw)))
  expect_gt(nrow(cw), 1000L)
  expect_true(any(cw$variable == "X_001"))
})

test_that("a wave downloads, reads and harmonizes end to end", {
  skip_if_offline_lb()
  lb_cache_dir(file.path(tempdir(), "lb_net_test"))

  d <- lb_load(2023, quiet = TRUE)
  expect_s3_class(d, "data.frame")
  expect_gt(nrow(d), 15000L)
  expect_true(all(c("X_001", "X_020", "lb_year") %in% names(d)))
  expect_equal(unique(d$lb_year), 2023L)
})

test_that("wave 2024 falls back to SPSS when its Stata file will not parse", {
  skip_if_offline_lb()
  lb_cache_dir(file.path(tempdir(), "lb_net_test"))

  # 2024 publishes no R file, so .dta is tried first...
  expect_equal(lb_pick_file(2024)$format, "dta")

  # ...but its S5 value-label table strands a label past the declared end of
  # its text block. Stata tolerates that; haven rejects the whole file. The
  # auto chain must therefore carry on to the SPSS twin rather than give up.
  d <- lb_load(2024, harmonize = FALSE, quiet = TRUE)
  expect_equal(attr(d, "lb_format"), "sav")
  expect_equal(nrow(d), 19214L)
  expect_true(all(c("S5", "IDENPA", "WT") %in% toupper(names(d))))

  # Pinning the unreadable format must fail loudly, with usable advice
  expect_error(lb_read(2024, format = "dta", quiet = TRUE),
               "unsupported features|format = \"sav\"")
})

test_that("text encoding is resolved rather than silently mangled", {
  skip_if_offline_lb()
  lb_cache_dir(file.path(tempdir(), "lb_net_test"))

  # haven assumes windows-1252 for files that declare no encoding, which does
  # not error on a UTF-8 file -- it just returns mojibake. Trying UTF-8 first
  # is what prevents that silent corruption.
  d <- lb_load(2024, harmonize = FALSE, quiet = TRUE)
  labs <- unlist(lapply(d, function(x) names(attr(x, "labels"))))
  expect_false(any(grepl("â€", labs)))   # the mojibake signature

  # Older waves genuinely are latin1 and must still read
  d20 <- lb_read(2020, format = "dta", quiet = TRUE)
  expect_gt(nrow(d20), 15000L)
})

test_that("waves that declare no text encoding still read", {
  skip_if_offline_lb()
  lb_cache_dir(file.path(tempdir(), "lb_net_test"))

  # Pre-Stata-14 files carry accented Spanish text with no declared encoding;
  # haven's windows-1252 default aborts on them and latin1 is retried.
  d <- lb_read(2020, format = "dta", quiet = TRUE)
  expect_gt(nrow(d), 15000L)
})

test_that("pooled waves stack and carry a wave identifier", {
  skip_if_offline_lb()
  lb_cache_dir(file.path(tempdir(), "lb_net_test"))

  p <- lb_pool(c(2020, 2023), keep = c("X_001", "X_020"), quiet = TRUE)
  expect_setequal(unique(p$lb_year), c(2020L, 2023L))
  expect_true(all(c("X_001", "X_020") %in% names(p)))
})

test_that("lb_refresh_urls() finds no drift from the built-in table", {
  skip_if_offline_lb()
  res <- lb_refresh_urls(c(2023, 2024), quiet = TRUE)
  expect_false(any(res$status == "missing"),
               info = "A built-in URL is gone from the site; update the manifest.")
})
