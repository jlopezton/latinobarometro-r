## ---------------------------------------------------------------------------
## Year -> data-file manifest.
##
## Latinobarometro publishes each wave under
##   https://www.latinobarometro.org/documents/LAT-<year>/<file>
## but the file NAMES are not systematic. Across waves the stem alternates
## between "latinobarometro-<year>-" and "latinobarometro<year>-", the format
## tag is variously "dta"/"stata", "r"/"r-rdata"/"r-rds"/"rdata"/"rds",
## "sav"/"spss", "sas"/"tpt", and later waves carry a version stamp
## ("-v1-0", "-v20190303", "-v20250817") that changes when a wave is re-released.
##
## The table below is therefore hardcoded (as in the 'enaho' package, which
## ships its INEI lookup tables as package data) rather than derived from a
## pattern. Entries marked "verified" were confirmed by fetching the wave page
## on 13 August 2026. Use lb_refresh_urls() to re-derive the table from the
## live site when a wave is re-released.
##
## Native R files exist only for 2013-2023. 1995-2011 predate R distribution
## entirely (dta / sav / tpt only) and 2024 ships csv, excel, spss and stata
## but no R file. lb_load() therefore falls back to the Stata .dta for those
## waves, read through haven.
## ---------------------------------------------------------------------------

lb_base_url <- function() "https://www.latinobarometro.org/documents"

lb_crosswalk_url <- function() {
  paste0(lb_base_url(), "/latinobarometro-serie-de-tiempo-1995-2024.xlsx")
}

lb_crosswalk_sheet <- function() "Serie de Tiempo 1995-2024"

#' Survey waves available from Latinobarometro
#'
#' Latinobarometro was not fielded every calendar year: there is no 1999,
#' 2012, 2014, 2019, 2021 or 2022 wave.
#'
#' @return An integer vector of available survey years.
#' @examples
#' lb_years()
#' @export
lb_years <- function() {
  # The `L` suffixes matter: a bare 2013 is a double, and c() would promote the
  # whole vector, contradicting the documented integer return type.
  c(1995:1998, 2000:2011, 2013L, 2015:2018, 2020L, 2023L, 2024L)
}

# Internal: one row per (year, format). `lang` is NA where the wave is not
# split by language. `verified` flags entries confirmed against the live site.
lb_manifest_table <- function() {
  rows <- list(
    # -- 1995-1998: dta / sav / tpt, no R --------------------------------------
    c(1995, "dta", NA, "latinobarometro-1995-dta.zip", TRUE),
    c(1995, "sav", NA, "latinobarometro-1995-sav.zip", TRUE),
    c(1996, "dta", NA, "latinobarometro-1996-dta.zip", TRUE),
    c(1997, "dta", NA, "latinobarometro-1997-dta.zip", TRUE),
    c(1998, "dta", NA, "latinobarometro-1998-dta.zip", TRUE),

    # -- 2000-2011: dta / sav / (tpt|sas), no R --------------------------------
    c(2000, "dta", NA, "latinobarometro-2000-dta.zip", TRUE),
    c(2000, "sav", NA, "latinobarometro-2000-sav.zip", TRUE),
    c(2001, "dta", NA, "latinobarometro-2001-dta.zip", TRUE),
    c(2002, "dta", NA, "latinobarometro-2002-dta.zip", TRUE),
    c(2003, "dta", NA, "latinobarometro-2003-dta.zip", TRUE),
    c(2004, "dta", NA, "latinobarometro-2004-dta.zip", TRUE),
    c(2005, "dta", NA, "latinobarometro-2005-dta.zip", TRUE),
    c(2006, "dta", NA, "latinobarometro-2006-dta.zip", TRUE),
    c(2007, "dta", NA, "latinobarometro-2007-dta.zip", TRUE),
    c(2008, "dta", NA, "latinobarometro-2008-dta.zip", TRUE),
    c(2009, "dta", NA, "latinobarometro-2009-dta.zip", TRUE),
    c(2010, "dta", NA, "latinobarometro-2010-dta.zip", TRUE),
    c(2011, "dta", NA, "latinobarometro-2011-dta.zip", TRUE),
    c(2011, "sav", NA, "latinobarometro-2011-sav.zip", TRUE),

    # -- 2013-2017: first waves with a native R file --------------------------
    c(2013, "r",   NA, "latinobarometro-2013-r.zip",   TRUE),
    c(2013, "dta", NA, "latinobarometro-2013-dta.zip", TRUE),
    c(2013, "sav", NA, "latinobarometro-2013-sav.zip", TRUE),
    c(2015, "r",   NA, "latinobarometro-2015-r.zip",   TRUE),
    c(2015, "dta", NA, "latinobarometro-2015-dta.zip", TRUE),
    c(2015, "sav", NA, "latinobarometro-2015-sav.zip", TRUE),
    # 2016 and 2017 drop the hyphen after "latinobarometro"
    c(2016, "r",   NA, "latinobarometro2016-r.zip",    TRUE),
    c(2016, "dta", NA, "latinobarometro2016-dta.zip",  TRUE),
    c(2016, "sav", NA, "latinobarometro2016-sav.zip",  TRUE),
    c(2017, "r",   NA, "latinobarometro2017-r.zip",    TRUE),
    c(2017, "dta", NA, "latinobarometro2017-dta.zip",  TRUE),
    c(2017, "sav", NA, "latinobarometro2017-sav.zip",  TRUE),

    # -- 2018: split by language; English has R + Stata, Spanish has R + dta ---
    c(2018, "r",   "eng", "latinobarometro-2018-eng-r-v20190303.zip",     TRUE),
    c(2018, "dta", "eng", "latinobarometro-2018-eng-stata-v20190303.zip", TRUE),
    c(2018, "sav", "eng", "latinobarometro-2018-eng-spss-v20190303.zip",  TRUE),
    c(2018, "r",   "esp", "latinobarometro-2018-esp-r-v20190303.zip",     TRUE),
    c(2018, "dta", "esp", "latinobarometro-2018-esp-dta-v20190303.zip",   TRUE),

    # -- 2020: rdata and rds shipped separately, both languages ----------------
    c(2020, "rds",   "eng", "latinobarometro-2020-eng-r-rds-v1-0.zip",   TRUE),
    c(2020, "rdata", "eng", "latinobarometro-2020-eng-r-rdata-v1-0.zip", TRUE),
    c(2020, "dta",   "eng", "latinobarometro-2020-eng-stata-v1-0.zip",   TRUE),
    c(2020, "sav",   "eng", "latinobarometro-2020-eng-spss-v1-0.zip",    TRUE),
    c(2020, "rds",   "esp", "latinobarometro-2020-esp-r-rds-v-0.zip",    TRUE),
    c(2020, "rdata", "esp", "latinobarometro-2020-esp-r-rdata-v1-0.zip", TRUE),
    c(2020, "dta",   "esp", "latinobarometro-2020-esp-stata-v1-0.zip",   TRUE),

    # -- 2023: single language, rdata + rds -----------------------------------
    c(2023, "rds",   NA, "latinobarometro-2023-rds-v1-0.zip",   TRUE),
    c(2023, "rdata", NA, "latinobarometro-2023-rdata-v1-0.zip", TRUE),
    c(2023, "dta",   NA, "latinobarometro-2023-stata-v1-0.zip", TRUE),
    c(2023, "sav",   NA, "latinobarometro-2023-spss-v1-0.zip",  TRUE),

    # -- 2024: no R file published; Stata is the fallback ---------------------
    c(2024, "dta", NA, "latinobarometro-2024-stata-v20250817.zip", TRUE),
    c(2024, "sav", NA, "latinobarometro-2024-spss-v20250817.zip",  TRUE),
    c(2024, "csv", NA, "latinobarometro-2024-csv-v20250817.zip",   TRUE)
  )

  out <- data.frame(
    year     = as.integer(vapply(rows, `[`, character(1), 1)),
    format   = vapply(rows, `[`, character(1), 2),
    lang     = vapply(rows, `[`, character(1), 3),
    file     = vapply(rows, `[`, character(1), 4),
    verified = as.logical(vapply(rows, `[`, character(1), 5)),
    stringsAsFactors = FALSE
  )
  out$url <- paste0(lb_base_url(), "/LAT-", out$year, "/", out$file)
  out
}

#' Data files published for a Latinobarometro wave
#'
#' Returns the package's built-in table of downloadable files for one or more
#' survey waves. This is a static snapshot of the Latinobarometro archive taken
#' on 13 August 2026; call [lb_refresh_urls()] to compare it against the live
#' site.
#'
#' @param year Optional integer vector of survey years. Defaults to all waves.
#' @param format Optional character vector of format codes to keep. One or more
#'   of `"rds"`, `"rdata"`, `"r"`, `"dta"`, `"sav"`, `"csv"`.
#'
#' @return A data frame with columns `year`, `format`, `lang`, `file`,
#'   `verified` and `url`.
#' @examples
#' lb_files(2023)
#' lb_files(format = "dta")
#' @export
lb_files <- function(year = NULL, format = NULL) {
  tab <- lb_manifest_table()
  if (!is.null(year)) {
    tab <- tab[tab$year %in% as.integer(year), , drop = FALSE]
  }
  if (!is.null(format)) {
    tab <- tab[tab$format %in% format, , drop = FALSE]
  }
  rownames(tab) <- NULL
  tab
}

# Internal: every candidate file for a wave, in preference order. With
# format = "auto" this is a chain, not a single guess, because a published file
# can be unreadable even when the URL is fine: the 2024 Stata file is written
# in a .dta format newer than haven supports, so the wave is only reachable
# through its SPSS twin. lb_read() walks this list and takes the first file it
# can actually parse.
lb_pick_files <- function(year, format = "auto", lang = "eng") {
  year <- lb_check_year(year)
  tab  <- lb_files(year)

  if (nrow(tab) == 0L) {
    stop("No data files known for wave ", year, ".", call. = FALSE)
  }

  pref <- if (identical(format, "auto")) {
    # Native R first, then Stata, then SPSS. See file header for why .dta is
    # the primary fallback and this file's header for why .sav backs it up.
    c("rds", "rdata", "r", "dta", "sav", "csv")
  } else {
    format
  }

  bad <- setdiff(pref, c("rds", "rdata", "r", "dta", "sav", "csv"))
  if (length(bad)) {
    stop("Unknown format(s): ", paste(bad, collapse = ", "), call. = FALSE)
  }

  out <- list()
  for (f in pref) {
    cand <- tab[tab$format == f, , drop = FALSE]
    if (nrow(cand) == 0L) next
    # Language preference: requested language, then unlabelled, then anything.
    hit <- cand[!is.na(cand$lang) & cand$lang == lang, , drop = FALSE]
    if (nrow(hit) == 0L) hit <- cand[is.na(cand$lang), , drop = FALSE]
    if (nrow(hit) == 0L) hit <- cand
    out[[length(out) + 1L]] <- hit[1L, , drop = FALSE]
  }

  if (length(out) == 0L) {
    stop(
      "Wave ", year, " does not publish format(s): ",
      paste(pref, collapse = ", "), ".\n",
      "Available for this wave: ",
      paste(unique(tab$format), collapse = ", "), ".",
      call. = FALSE
    )
  }

  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}

# Internal: the single most-preferred file for a wave.
lb_pick_file <- function(year, format = "auto", lang = "eng") {
  lb_pick_files(year, format = format, lang = lang)[1L, , drop = FALSE]
}

lb_check_year <- function(year) {
  if (length(year) != 1L || is.na(suppressWarnings(as.integer(year)))) {
    stop("`year` must be a single four-digit survey year, e.g. 2020.",
         call. = FALSE)
  }
  year <- as.integer(year)
  if (!year %in% lb_years()) {
    stop(
      "No Latinobarometro wave for ", year, ".\n",
      "Available waves: ", paste(lb_years(), collapse = ", "), ".",
      call. = FALSE
    )
  }
  year
}
