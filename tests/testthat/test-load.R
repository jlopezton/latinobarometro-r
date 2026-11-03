test_that("lb_cache_dir() honours an explicit path and can be cleared", {
  d <- file.path(tempdir(), "lb_test_cache")
  expect_equal(normalizePath(lb_cache_dir(d)), normalizePath(d))
  expect_true(dir.exists(d))

  writeLines("x", file.path(d, "sentinel.txt"))
  lb_clear_cache()
  expect_false(file.exists(file.path(d, "sentinel.txt")))
})

test_that("lb_format_ext() dispatches the ambiguous 'r' archives on both", {
  # The 2013-2018 '-r.zip' archives are not self-describing: some hold .RData,
  # some .rds. Both must be accepted.
  expect_setequal(lb_format_ext("r"), c("rds", "rdata", "rda"))
  expect_equal(lb_format_ext("dta"), "dta")
  expect_error(lb_format_ext("parquet"), "Unknown format")
})

test_that("lb_choose_file() prefers English and avoids Spanish", {
  files <- c("/tmp/Latinobarometro_2018_Eng.dta",
             "/tmp/Latinobarometro_2018_Esp.dta")
  expect_match(lb_choose_file(files, 2018, quiet = TRUE), "Eng")

  # No English available: a neutral file beats the Spanish one
  files <- c("/tmp/Latinobarometro_2016.dta", "/tmp/Latinobarometro_2016_Esp.dta")
  expect_match(lb_choose_file(files, 2016, quiet = TRUE), "2016\\.dta$")

  # Only Spanish: take it, but say so
  expect_message(
    lb_choose_file(c("/tmp/lb_2016_esp.dta", "/tmp/lb_2016_esp_b.dta"), 2016),
    "Spanish"
  )
})

test_that("lb_rbind_fill() stacks waves with differing columns", {
  a <- data.frame(X_001 = 1:2, P1 = c("a", "b"), stringsAsFactors = FALSE)
  b <- data.frame(X_001 = 3L, P2 = TRUE)

  out <- lb_rbind_fill(list(a, b))
  expect_equal(nrow(out), 3L)
  expect_setequal(names(out), c("X_001", "P1", "P2"))
  expect_true(is.na(out$P1[3]))
  expect_true(all(is.na(out$P2[1:2])))
})

test_that("lb_rbind_fill() drops incompatible labels rather than failing", {
  # Response options get reworded between waves, so the same column arrives
  # with different label sets. Stacking must still succeed.
  a <- data.frame(x = haven::labelled(c(1, 2), c(Yes = 1, No = 2)))
  b <- data.frame(x = c(1, 2))

  out <- lb_rbind_fill(list(a, b))
  expect_equal(nrow(out), 4L)
  expect_equal(as.numeric(out$x), c(1, 2, 1, 2))
})

test_that("lb_load() rejects add_population without harmonize", {
  expect_error(
    lb_load(2023, harmonize = FALSE, add_population = TRUE),
    "requires harmonize = TRUE"
  )
})
