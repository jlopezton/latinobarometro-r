test_that("country code mapping is complete and ISO-3 shaped", {
  codes <- lb_country_codes()
  expect_length(codes, 19L)
  expect_true(all(nchar(codes) == 3L))
  expect_true(all(grepl("^[A-Z]{3}$", codes)))
  expect_equal(unname(codes["32"]), "ARG")
  expect_equal(unname(codes["862"]), "VEN")
  expect_false(any(duplicated(codes)))
})

test_that("lb_add_population() refuses unharmonized data", {
  expect_error(
    lb_add_population(data.frame(idenpa = 1), year = 2023),
    "X_001 and X_020"
  )
})

test_that("wt_lac rescales samples to population shares", {
  # Two countries, equal sample sizes, populations 2:1. The larger country's
  # respondents should carry twice the weight.
  dat <- data.frame(
    X_001 = c(32, 32, 152, 152),   # ARG, CHL
    X_020 = c(1, 1, 1, 1)
  )
  attr(dat, "lb_year") <- 2023

  pop <- data.frame(countrycode = c("ARG", "CHL"),
                    population  = c(4e7, 2e7), stringsAsFactors = FALSE)

  # Substitute the World Bank fetch so the test stays offline
  local_mocked_bindings(lb_population = function(...) pop)

  out <- lb_add_population(dat, year = 2023, quiet = TRUE)

  # ignore_attr throughout: lb_add_population() labels every column it creates,
  # and waldo compares attributes by default
  expect_equal(out$countrycode, c("ARG", "ARG", "CHL", "CHL"), ignore_attr = TRUE)
  expect_equal(out$total_sample, c(2, 2, 2, 2), ignore_attr = TRUE)
  expect_equal(out$wt_lac, c(2e7, 2e7, 1e7, 1e7), ignore_attr = TRUE)
  # Weights sum to total population, which is the point of the rescaling
  expect_equal(sum(out$wt_lac), 6e7)

  # The labels themselves are part of the contract, so assert them explicitly
  expect_equal(attr(out$wt_lac, "label"),
               "Population-scaled weight for pooled LAC estimates")
  expect_equal(attr(out$countrycode, "label"),
               "ISO 3166-1 alpha-3 country code")
})

test_that("unmapped country codes yield NA weights rather than wrong ones", {
  dat <- data.frame(X_001 = c(32, 9999), X_020 = c(1, 1))
  pop <- data.frame(countrycode = "ARG", population = 4e7,
                    stringsAsFactors = FALSE)
  local_mocked_bindings(lb_population = function(...) pop)

  out <- lb_add_population(dat, year = 2023, quiet = TRUE)
  expect_true(is.na(out$countrycode[2]))
  expect_true(is.na(out$wt_lac[2]))
  expect_false(is.na(out$wt_lac[1]))
})

test_that("lb_as_numeric() survives labelled and factor input", {
  expect_equal(lb_as_numeric(c(1, 2)), c(1, 2))
  expect_equal(lb_as_numeric(factor(c("1", "2"))), c(1, 2))
  lab <- haven::labelled(c(32, 152), c(Argentina = 32, Chile = 152))
  expect_equal(lb_as_numeric(lab), c(32, 152))
})
