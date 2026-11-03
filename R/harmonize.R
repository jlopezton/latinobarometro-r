## ---------------------------------------------------------------------------
## Cross-wave harmonization via the official time-series crosswalk.
##
## Port of step 6 of the Stata program, including the candidate-spelling trick:
## the crosswalk's source-variable spelling is not always the literal raw
## variable name. A period in the crosswalk (e.g. "P62N.A") corresponds to an
## underscore in the real data in some waves ("p62n_a") and to nothing at all
## in others ("p62na"). Rather than committing to one rule, every plausible
## spelling is generated and whichever one matches a real column wins. That
## logic was validated in Stata against a hand-built 2020 rename list:
## 5,809 / 5,809 exact matches, zero discrepancies.
## ---------------------------------------------------------------------------

#' Download and read the Latinobarometro time-series crosswalk
#'
#' The crosswalk is the official mapping between each wave's raw variable names
#' and the standardized cross-wave names (`X_001`, `P12ST_A`, and so on),
#' published by Latinobarometro as a single spreadsheet.
#'
#' @param force Re-download even if a cached copy exists.
#' @param quiet Suppress progress messages.
#'
#' @return A data frame with columns `variable`, `title_es`, `title_en`,
#'   `n_points`, and one `LAT<year>` column per wave holding that wave's raw
#'   variable name.
#' @examples
#' \donttest{
#' lb_cache_dir(file.path(tempdir(), "lb_demo"))
#' try(head(lb_crosswalk()))
#' }
#' @export
lb_crosswalk <- function(force = FALSE, quiet = FALSE) {
  cache <- lb_cache_dir()
  xlsx  <- file.path(cache, "latinobarometro-serie-de-tiempo-1995-2024.xlsx")

  if (!file.exists(xlsx) || isTRUE(force)) {
    if (!quiet) message("Downloading time-series crosswalk ...")
    ok <- tryCatch({
      old <- options(timeout = max(600, getOption("timeout", 60)))
      on.exit(options(old), add = TRUE)
      utils::download.file(lb_crosswalk_url(), destfile = xlsx,
                           mode = "wb", quiet = quiet)
      TRUE
    }, error = function(e) structure(FALSE, msg = conditionMessage(e)),
       warning = function(w) structure(FALSE, msg = conditionMessage(w)))

    if (!isTRUE(ok) || !file.exists(xlsx) || file.size(xlsx) < 1024) {
      unlink(xlsx)
      stop("Could not download the crosswalk from ", lb_crosswalk_url(), ".\n",
           if (!is.null(attr(ok, "msg"))) paste0("Reason: ", attr(ok, "msg")),
           call. = FALSE)
    }
  } else if (!quiet) {
    message("Using cached crosswalk (force = TRUE re-downloads).")
  }

  # Read positionally. The header row carries special characters (e.g.
  # "Nn puntos") that make unreliable column names, so skip it and name the
  # 28 columns by position: 4 descriptive columns then 24 wave columns.
  raw <- readxl::read_excel(xlsx, sheet = lb_crosswalk_sheet(),
                            col_names = FALSE, col_types = "text",
                            skip = 1, .name_repair = "minimal")
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)

  wave_years <- lb_years()
  expected <- 4L + length(wave_years)
  if (ncol(raw) < expected) {
    stop("The crosswalk sheet has ", ncol(raw), " columns; ", expected,
         " were expected. The published file layout may have changed - ",
         "please open an issue.", call. = FALSE)
  }
  raw <- raw[, seq_len(expected), drop = FALSE]
  names(raw) <- c("variable", "title_es", "title_en", "n_points",
                  paste0("LAT", wave_years))

  raw[] <- lapply(raw, function(col) {
    col <- as.character(col)
    col[is.na(col)] <- ""
    trimws(col)
  })
  raw
}

#' Harmonize variable names across waves
#'
#' Renames a wave's raw variables to the standardized cross-wave names given by
#' the Latinobarometro time-series crosswalk, and attaches the crosswalk's
#' English question text as each column's variable label.
#'
#' @param data A data frame from [lb_read()].
#' @param year Survey year. Defaults to the `lb_year` attribute set by
#'   [lb_read()].
#' @param crosswalk An optional crosswalk from [lb_crosswalk()], to avoid
#'   re-reading it when harmonizing many waves.
#' @param force Re-download the crosswalk even if cached.
#' @param quiet Suppress progress messages.
#'
#' @return The data frame with harmonized names and variable labels. Columns
#'   absent from the crosswalk keep their raw (lowercased) names.
#' @examples
#' # The crosswalk is normally downloaded, but any data frame of the same shape
#' # works, which makes the renaming easy to see:
#' cw <- data.frame(
#'   variable = c("X_001", "X_020"),
#'   title_es = c("Pais", "Ponderador"),
#'   title_en = c("Country", "Sample weight"),
#'   n_points = c("", ""),
#'   LAT2023  = c("idenpa", "wt"),
#'   stringsAsFactors = FALSE
#' )
#' raw <- data.frame(idenpa = c(32, 152), wt = c(1, 1.2), notinxwalk = c(9, 9))
#' out <- lb_harmonize(raw, year = 2023, crosswalk = cw)
#' names(out)
#' attr(out$X_001, "label")
#'
#' \donttest{
#' # In practice the crosswalk comes from Latinobarometro
#' lb_cache_dir(file.path(tempdir(), "lb_demo"))
#' try(lb_harmonize(lb_read(2023)))
#' }
#' @export
lb_harmonize <- function(data,
                         year = attr(data, "lb_year"),
                         crosswalk = NULL,
                         force = FALSE,
                         quiet = FALSE) {
  stopifnot(is.data.frame(data))
  if (is.null(year)) {
    stop("`year` is missing and `data` carries no lb_year attribute. ",
         "Pass year explicitly.", call. = FALSE)
  }
  year <- lb_check_year(year)

  cw <- crosswalk %||% lb_crosswalk(force = force, quiet = quiet)
  col <- paste0("LAT", year)
  if (!col %in% names(cw)) {
    stop("The crosswalk has no column for wave ", year, " (expected ", col,
         ").", call. = FALSE)
  }

  cw <- cw[nzchar(cw[[col]]) & nzchar(cw$variable), , drop = FALSE]
  if (nrow(cw) == 0L) {
    warning("The crosswalk lists no variables for wave ", year,
            "; returning data unchanged.", call. = FALSE)
    return(data)
  }

  # Build raw-name -> (new name, English label) lookups over all candidate
  # spellings. Later rows do not overwrite earlier ones, matching the Stata
  # loop's first-wins behaviour.
  map_new <- new.env(parent = emptyenv())
  map_lab <- new.env(parent = emptyenv())
  for (i in seq_len(nrow(cw))) {
    raw_name <- cw[[col]][i]
    cands <- unique(lb_name_candidates(raw_name))
    for (cand in cands) {
      if (!nzchar(cand)) next
      if (!exists(cand, envir = map_new, inherits = FALSE)) {
        assign(cand, cw$variable[i], envir = map_new)
        assign(cand, cw$title_en[i], envir = map_lab)
      }
    }
  }

  # Match on a normalized key rather than the literal column name. Waves read
  # from a native R file can legitimately hold periods in their names
  # ("P12ST.A") where the same wave read from .dta cannot ("p12st_a"), and the
  # crosswalk uses its own third spelling. Normalizing both sides is what makes
  # the match format-independent.
  names(data) <- tolower(names(data))
  keys <- lb_make_name(names(data))
  new_names <- names(data)
  matched <- 0L

  for (j in seq_along(keys)) {
    key <- keys[j]
    if (!exists(key, envir = map_new, inherits = FALSE)) next
    lab <- get(key, envir = map_lab, inherits = FALSE)
    if (nzchar(lab)) attr(data[[j]], "label") <- lab
    new_names[j] <- get(key, envir = map_new, inherits = FALSE)
    matched <- matched + 1L
  }

  dup <- duplicated(new_names)
  if (any(dup)) {
    warning("Crosswalk maps several raw variables of wave ", year,
            " onto the same standardized name(s): ",
            paste(unique(new_names[dup]), collapse = ", "),
            ". Later columns keep their raw names.", call. = FALSE)
    new_names[dup] <- names(data)[dup]
  }

  names(data) <- new_names
  attr(data, "lb_harmonized") <- TRUE
  if (!quiet) {
    message("Harmonized ", matched, " of ", ncol(data),
            " variables for wave ", year, ".")
  }
  data
}

# Internal: plausible raw spellings for a crosswalk entry. See file header.
lb_name_candidates <- function(raw) {
  c(
    lb_make_name(gsub(".", "_", raw, fixed = TRUE)),
    lb_make_name(gsub(".", "",  raw, fixed = TRUE)),
    lb_make_name(raw)
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x
