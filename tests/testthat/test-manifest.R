# Offline tests: the manifest and its selection rules. These run everywhere,
# including on CRAN, because they touch no network.

test_that("lb_years() covers the waves that were actually fielded", {
  y <- lb_years()
  expect_type(y, "integer")
  expect_true(all(c(1995, 2013, 2020, 2024) %in% y))
  # Latinobarometro was not fielded in these years
  expect_false(any(c(1999, 2012, 2014, 2019, 2021, 2022) %in% y))
  expect_equal(length(y), 24L)
})

test_that("every wave has at least a Stata file", {
  for (y in lb_years()) {
    expect_true("dta" %in% lb_files(y)$format,
                info = paste("wave", y, "has no dta entry"))
  }
})

test_that("the manifest has exactly one entry per year/format/lang", {
  tab <- lb_files()
  key <- paste(tab$year, tab$format, tab$lang)
  expect_false(any(duplicated(key)))
})

test_that("manifest URLs are well formed", {
  tab <- lb_files()
  expect_true(all(grepl("^https://www\\.latinobarometro\\.org/documents/LAT-",
                        tab$url)))
  expect_true(all(grepl("\\.zip$", tab$url)))
  expect_true(all(mapply(grepl, paste0("LAT-", tab$year, "/"), tab$url)))
})

test_that("format = 'auto' prefers native R and falls back to Stata", {
  # 2023 publishes rds -> should win over dta
  expect_equal(lb_pick_file(2023)$format, "rds")
  # 2013 publishes only the undifferentiated 'r' archive
  expect_equal(lb_pick_file(2013)$format, "r")
  # 1995 and 2024 publish no R file at all -> Stata fallback
  expect_equal(lb_pick_file(1995)$format, "dta")
  expect_equal(lb_pick_file(2024)$format, "dta")
})

test_that("format = 'auto' yields a fallback chain, not a single guess", {
  # A published file can be unreadable even when its URL is fine: the 2024
  # .dta is written in a format newer than haven supports, so the chain has to
  # continue past it to the SPSS twin.
  chain <- lb_pick_files(2024)
  expect_gt(nrow(chain), 1L)
  expect_equal(chain$format[1], "dta")
  expect_true("sav" %in% chain$format)
  expect_lt(which(chain$format == "dta"), which(chain$format == "sav"))

  # Native R still leads where it exists
  expect_equal(lb_pick_files(2023)$format[1], "rds")

  # Pinning a format gives exactly one candidate, so failures surface
  expect_equal(nrow(lb_pick_files(2024, format = "dta")), 1L)
})

test_that("language preference is honoured where waves are split", {
  expect_equal(lb_pick_file(2018, format = "dta", lang = "eng")$lang, "eng")
  expect_equal(lb_pick_file(2018, format = "dta", lang = "esp")$lang, "esp")
  # 2023 is not split by language; asking for English still resolves
  expect_true(is.na(lb_pick_file(2023, format = "dta", lang = "eng")$lang))
})

test_that("2016 and 2017 keep their hyphenless stem", {
  # This was a live bug in the Stata version: 2016 was assumed to follow the
  # hyphenated pattern and did not.
  expect_equal(lb_pick_file(2016, format = "dta")$file,
               "latinobarometro2016-dta.zip")
  expect_equal(lb_pick_file(2017, format = "dta")$file,
               "latinobarometro2017-dta.zip")
})

test_that("invalid years and formats are rejected with a useful message", {
  expect_error(lb_check_year(2019), "No Latinobarometro wave for 2019")
  expect_error(lb_check_year("banana"), "four-digit survey year")
  expect_error(lb_check_year(c(2020, 2023)), "single four-digit")
  expect_error(lb_pick_file(2020, format = "parquet"), "Unknown format")
  expect_error(lb_pick_file(2024, format = "rds"), "does not publish format")
})
