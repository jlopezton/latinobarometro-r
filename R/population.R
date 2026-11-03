## ---------------------------------------------------------------------------
## Population-scaled weights.
##
## Port of step 7 of the Stata program. The Stata version calls wbopendata;
## the R equivalent is the WDI package, kept in Suggests and checked for at
## run time with the same friendly install message.
## ---------------------------------------------------------------------------

# Latinobarometro codes countries with ISO 3166-1 numeric in X_001; the World
# Bank keys on ISO 3166-1 alpha-3. Same mapping as the Stata program.
lb_country_codes <- function() {
  c(
    "32"  = "ARG", "68"  = "BOL", "76"  = "BRA", "152" = "CHL",
    "170" = "COL", "188" = "CRI", "214" = "DOM", "218" = "ECU",
    "222" = "SLV", "320" = "GTM", "340" = "HND", "484" = "MEX",
    "558" = "NIC", "591" = "PAN", "600" = "PRY", "604" = "PER",
    "724" = "ESP", "858" = "URY", "862" = "VEN"
  )
}

#' Add country-population-scaled survey weights
#'
#' Merges World Bank total-population figures onto a harmonized wave and builds
#' `wt_lac`, a weight that rescales each national sample so that countries enter
#' pooled regional estimates in proportion to their population rather than their
#' sample size.
#'
#' `wt_lac` is a weight for pooled *point estimates*. It is not a frequency
#' weight, and it does not describe the sampling design. For standard errors,
#' declare the actual national design with `survey::svydesign()` using the
#' design variables published with the wave.
#'
#' Requires the \pkg{WDI} package and the harmonized variables `X_001`
#' (country) and `X_020` (sample weight), so run [lb_harmonize()] first.
#'
#' @param data A harmonized data frame, from [lb_harmonize()].
#' @param year Survey year. Defaults to the `lb_year` attribute.
#' @param force Re-fetch population data even if cached.
#' @param quiet Suppress progress messages.
#'
#' @return The data frame with `countrycode`, `population`, `total_sample` and
#'   `wt_lac` added.
#' @examples
#' \donttest{
#' lb_cache_dir(file.path(tempdir(), "lb_demo"))
#' try(lb_add_population(lb_harmonize(lb_read(2023))))
#' }
#' @export
lb_add_population <- function(data,
                              year = attr(data, "lb_year"),
                              force = FALSE,
                              quiet = FALSE) {
  stopifnot(is.data.frame(data))
  if (is.null(year)) {
    stop("`year` is missing and `data` carries no lb_year attribute.",
         call. = FALSE)
  }
  year <- lb_check_year(year)

  missing_vars <- setdiff(c("X_001", "X_020"), names(data))
  if (length(missing_vars)) {
    stop("lb_add_population() needs the harmonized variables ",
         paste(missing_vars, collapse = " and "),
         ". Run lb_harmonize() first (or lb_load(harmonize = TRUE)).",
         call. = FALSE)
  }

  pop <- lb_population(year, force = force, quiet = quiet)

  codes <- lb_country_codes()
  iso_num <- as.character(lb_as_numeric(data$X_001))
  data$countrycode <- unname(codes[iso_num])
  attr(data$countrycode, "label") <- "ISO 3166-1 alpha-3 country code"

  unmatched <- unique(iso_num[is.na(data$countrycode) & !is.na(iso_num)])
  if (length(unmatched) && !quiet) {
    message("No ISO-3 mapping for X_001 code(s): ",
            paste(unmatched, collapse = ", "),
            ". Those rows get a missing weight.")
  }

  data$population <- pop$population[match(data$countrycode, pop$countrycode)]

  wt <- lb_as_numeric(data$X_020)
  totals <- stats::ave(wt, data$countrycode, FUN = function(x) sum(x, na.rm = TRUE))
  totals[is.na(data$countrycode)] <- NA_real_
  data$total_sample <- totals
  data$wt_lac <- wt * data$population / totals

  attr(data$population,   "label") <- "Country population (World Bank, SP.POP.TOTL)"
  attr(data$total_sample, "label") <- "Sum of sample weights within country"
  attr(data$wt_lac,       "label") <- "Population-scaled weight for pooled LAC estimates"

  if (!quiet) {
    n_na <- sum(is.na(data$wt_lac))
    message("Added wt_lac (", n_na, " of ", nrow(data),
            " rows missing a weight).")
  }
  data
}

# Internal: World Bank population for one year, cached on disk.
lb_population <- function(year, force = FALSE, quiet = FALSE) {
  cache <- file.path(lb_cache_dir(), "population")
  dir.create(cache, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(cache, paste0("wb_population_", year, ".rds"))

  if (file.exists(path) && !isTRUE(force)) {
    if (!quiet) message("Using cached World Bank population data.")
    return(readRDS(path))
  }

  if (!requireNamespace("WDI", quietly = TRUE)) {
    stop(
      "lb_add_population() requires the WDI package, which is not installed.\n",
      "Install it with:  install.packages(\"WDI\")",
      call. = FALSE
    )
  }

  if (!quiet) message("Fetching World Bank population data for ", year, " ...")
  raw <- tryCatch(
    WDI::WDI(country = "all", indicator = "SP.POP.TOTL",
             start = year, end = year),
    error = function(e) {
      stop("World Bank population request failed: ", conditionMessage(e),
           call. = FALSE)
    }
  )

  value_col <- intersect(c("SP.POP.TOTL", "sp.pop.totl", "SP_POP_TOTL"),
                         names(raw))
  if (length(value_col) == 0L) {
    stop("Could not find the SP.POP.TOTL column in the WDI response. ",
         "Columns returned: ", paste(names(raw), collapse = ", "),
         call. = FALSE)
  }
  if (!"iso3c" %in% names(raw)) {
    stop("The WDI response has no iso3c column; cannot map to Latinobarometro ",
         "country codes.", call. = FALSE)
  }

  out <- data.frame(
    countrycode = toupper(as.character(raw$iso3c)),
    population  = as.numeric(raw[[value_col[1L]]]),
    stringsAsFactors = FALSE
  )
  out <- out[!is.na(out$countrycode) & nzchar(out$countrycode), , drop = FALSE]
  out <- out[!duplicated(out$countrycode), , drop = FALSE]

  saveRDS(out, path)
  out
}

# Internal: strip haven labels so arithmetic and comparison are safe whether
# the wave came from .dta, .sav or a native R file.
lb_as_numeric <- function(x) {
  if (inherits(x, "haven_labelled")) x <- haven::zap_labels(x)
  if (is.factor(x)) x <- as.character(x)
  suppressWarnings(as.numeric(x))
}
