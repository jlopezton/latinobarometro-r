# Offline tests for the name-matching logic. The candidate-spelling rule is
# the part most likely to regress, so it is tested against the real
# irregularities observed in the crosswalk.

test_that("lb_make_name() reproduces Stata's ustrtoname() behaviour", {
  expect_equal(lb_make_name("P62N.A"), "p62n_a")
  expect_equal(lb_make_name("S1"), "s1")
  expect_equal(lb_make_name("Nn puntos"), "nn_puntos")
  expect_equal(lb_make_name("2019var"), "_2019var")
  expect_equal(lb_make_name("already_ok"), "already_ok")
})

test_that("lb_name_candidates() covers both period conventions", {
  # A period in the crosswalk is an underscore in some waves and nothing in
  # others, so both spellings must be generated.
  cands <- lb_name_candidates("P62N.A")
  expect_true("p62n_a" %in% cands)
  expect_true("p62na" %in% cands)

  # No period: all candidates collapse to the same name
  expect_equal(unique(lb_name_candidates("S1")), "s1")
})

test_that("lb_clean_names() works on data frames and character vectors", {
  df <- data.frame(`P62N.A` = 1, S1 = 2, check.names = FALSE)
  expect_equal(names(lb_clean_names(df)), c("p62n_a", "s1"))
  expect_equal(lb_clean_names(c("A.B", "C")), c("a_b", "c"))
})

test_that("lb_harmonize() renames, labels, and leaves unmatched columns alone", {
  cw <- data.frame(
    variable = c("X_001", "X_020", "P12ST_A"),
    title_es = c("Pais", "Ponderador", "Confianza"),
    title_en = c("Country", "Weight", "Trust in institutions"),
    n_points = c("", "", ""),
    LAT2023  = c("idenpa", "wt", "P12ST.A"),
    stringsAsFactors = FALSE
  )

  dat <- data.frame(idenpa = c(32, 152), wt = c(1, 1.2),
                    P12ST.A = c(1, 2), notinxwalk = c(9, 9),
                    check.names = FALSE)

  out <- lb_harmonize(dat, year = 2023, crosswalk = cw, quiet = TRUE)

  expect_equal(names(out), c("X_001", "X_020", "P12ST_A", "notinxwalk"))
  expect_equal(attr(out$X_001, "label"), "Country")
  expect_equal(attr(out$P12ST_A, "label"), "Trust in institutions")
  expect_null(attr(out$notinxwalk, "label"))
  # ignore_attr: the values are what matter here; the label is asserted above
  expect_equal(out$X_001, c(32, 152), ignore_attr = TRUE)
  expect_true(attr(out, "lb_harmonized"))
})

test_that("lb_harmonize() matches regardless of how periods survived the format", {
  cw <- data.frame(
    variable = "P12ST_A", title_es = "", title_en = "Trust", n_points = "",
    LAT2023  = "P12ST.A", stringsAsFactors = FALSE
  )
  # From .dta the column arrives as p12st_a; from a native R file it can keep
  # the period. Both must resolve to the same standardized name.
  for (raw in c("p12st_a", "P12ST.A", "p12sta")) {
    dat <- data.frame(x = 1:2)
    names(dat) <- raw
    out <- lb_harmonize(dat, year = 2023, crosswalk = cw, quiet = TRUE)
    expect_equal(names(out), "P12ST_A", info = raw)
  }
})

test_that("lb_harmonize() matches a crosswalk period against a no-separator name", {
  cw <- data.frame(
    variable = "P62N_A", title_es = "", title_en = "Q62 N A", n_points = "",
    LAT2023  = "P62N.A", stringsAsFactors = FALSE
  )
  # Real data spells it with no separator at all
  dat <- data.frame(p62na = 1:2)
  out <- lb_harmonize(dat, year = 2023, crosswalk = cw, quiet = TRUE)
  expect_equal(names(out), "P62N_A")
})

test_that("lb_harmonize() warns rather than silently colliding names", {
  cw <- data.frame(
    variable = c("X_001", "X_001"),
    title_es = c("", ""), title_en = c("Country", "Country"),
    n_points = c("", ""),
    LAT2023  = c("idenpa", "pais"), stringsAsFactors = FALSE
  )
  dat <- data.frame(idenpa = 1, pais = 2)
  expect_warning(
    out <- lb_harmonize(dat, year = 2023, crosswalk = cw, quiet = TRUE),
    "same standardized name"
  )
  expect_equal(names(out), c("X_001", "pais"))
})

test_that("lb_harmonize() needs a year", {
  expect_error(lb_harmonize(data.frame(a = 1)), "lb_year attribute")
})
