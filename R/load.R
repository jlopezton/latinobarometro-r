#' Load a Latinobarometro wave
#'
#' The main entry point: downloads the wave if needed, reads it, and by default
#' harmonizes variable names across waves using the official time-series
#' crosswalk. Equivalent to the `latinobarometro` command in the companion
#' Stata package, but returns a data frame instead of replacing the dataset in
#' memory.
#'
#' @inheritParams lb_read
#' @param harmonize Rename variables to the standardized cross-wave names. See
#'   [lb_harmonize()].
#' @param add_population Merge World Bank population totals and build the
#'   `wt_lac` pooled weight. Requires `harmonize = TRUE` and the \pkg{WDI}
#'   package. See [lb_add_population()].
#' @param crosswalk An optional crosswalk from [lb_crosswalk()], reused across
#'   calls when loading several waves.
#'
#' @return A data frame with one row per respondent.
#' @seealso [lb_pool()] to stack several harmonized waves.
#' @examples
#' \donttest{
#' lb_cache_dir(file.path(tempdir(), "lb_demo"))
#' # Requires internet access to latinobarometro.org
#' try(lb_load(2023))
#' }
#' @export
lb_load <- function(year,
                    harmonize = TRUE,
                    add_population = FALSE,
                    format = "auto",
                    lang = c("eng", "esp"),
                    crosswalk = NULL,
                    force = FALSE,
                    quiet = FALSE) {
  lang <- match.arg(lang)

  if (isTRUE(add_population) && !isTRUE(harmonize)) {
    stop("add_population = TRUE requires harmonize = TRUE: the weight is built ",
         "from the standardized X_001 and X_020 variables.", call. = FALSE)
  }

  dat <- lb_read(year, format = format, lang = lang,
                 download = TRUE, force = force, quiet = quiet)

  if (isTRUE(harmonize)) {
    dat <- lb_harmonize(dat, year = year, crosswalk = crosswalk,
                        force = force, quiet = quiet)
  }
  if (isTRUE(add_population)) {
    dat <- lb_add_population(dat, year = year, force = force, quiet = quiet)
  }

  dat$lb_year <- lb_check_year(year)
  attr(dat$lb_year, "label") <- "Survey wave (harmonized)"
  dat
}

#' Load and stack several harmonized waves
#'
#' Loads each requested wave with [lb_load()] and row-binds them into a single
#' panel, filling variables absent from a given wave with `NA`. This is what
#' harmonized names are for: without them the same question carries a different
#' name in every wave.
#'
#' Waves are read from the Stata `.dta` archive by default rather than from
#' native R files, so that every wave comes back with the same column types.
#' Pass `format = "auto"` if you would rather have the native R file where one
#' exists.
#'
#' @param years Integer vector of survey years. See [lb_years()].
#' @param keep Optional character vector of standardized variable names to
#'   retain. Keeping only what you need makes a big difference: a full pooled
#'   panel runs to several thousand columns.
#' @inheritParams lb_load
#'
#' @return A data frame with an `lb_year` column identifying the wave.
#' @examples
#' \donttest{
#' lb_cache_dir(file.path(tempdir(), "lb_demo"))
#' try(lb_pool(c(2020, 2023), keep = c("X_001", "X_020", "P12ST_A")))
#' }
#' @export
lb_pool <- function(years,
                    keep = NULL,
                    add_population = FALSE,
                    format = "dta",
                    lang = c("eng", "esp"),
                    force = FALSE,
                    quiet = FALSE) {
  lang  <- match.arg(lang)
  years <- vapply(years, lb_check_year, integer(1))

  cw <- lb_crosswalk(force = force, quiet = quiet)

  waves <- lapply(years, function(y) {
    dat <- lb_load(y, harmonize = TRUE, add_population = add_population,
                   format = format, lang = lang, crosswalk = cw,
                   force = force, quiet = quiet)
    if (!is.null(keep)) {
      cols <- intersect(unique(c(keep, "lb_year")), names(dat))
      missing_cols <- setdiff(keep, names(dat))
      if (length(missing_cols) && !quiet) {
        message("Wave ", y, " has no: ",
                paste(missing_cols, collapse = ", "), ".")
      }
      dat <- dat[, cols, drop = FALSE]
    }
    dat
  })

  lb_rbind_fill(waves)
}

# Internal: rbind data frames with differing columns, filling gaps with NA.
# Written against base R so the package does not depend on dplyr.
lb_rbind_fill <- function(dfs) {
  dfs <- Filter(function(d) !is.null(d) && nrow(d) > 0L, dfs)
  if (length(dfs) == 0L) return(data.frame())
  all_cols <- unique(unlist(lapply(dfs, names)))

  filled <- lapply(dfs, function(d) {
    miss <- setdiff(all_cols, names(d))
    for (m in miss) d[[m]] <- NA
    d[, all_cols, drop = FALSE]
  })

  # rbind() refuses to combine haven_labelled columns with differing label
  # sets, which happens whenever a response option was reworded between waves.
  # Strip the labelled class from any such column and keep the underlying
  # codes; the wave-specific labels remain retrievable per wave.
  for (col in all_cols) {
    classes <- unique(unlist(lapply(filled, function(d) class(d[[col]])[1L])))
    if (length(classes) > 1L) {
      for (i in seq_along(filled)) {
        x <- filled[[i]][[col]]
        if (inherits(x, "haven_labelled")) x <- haven::zap_labels(x)
        filled[[i]][[col]] <- x
      }
    }
  }

  out <- do.call(rbind, lapply(filled, as.data.frame, stringsAsFactors = FALSE))
  rownames(out) <- NULL
  out
}
