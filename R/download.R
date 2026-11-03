## ---------------------------------------------------------------------------
## Download + unzip.
##
## As in the Stata package, latinobarometro.org is the ONLY source. There is
## deliberately no fallback mirror: Latinobarometro's terms of use prohibit
## redistribution, so a mirror would put users in breach. If the site is down,
## the correct behaviour is to fail loudly rather than silently serve a copy
## from somewhere else.
## ---------------------------------------------------------------------------

#' Download a Latinobarometro wave
#'
#' Fetches one survey wave from latinobarometro.org into the cache and unzips
#' it. Subsequent calls reuse the cached copy unless `force = TRUE`.
#'
#' The Latinobarometro archive is the only source used. This package never
#' redistributes survey data, and never falls back to a mirror: doing so would
#' breach the Latinobarometro terms of use, which prohibit republishing their
#' data elsewhere.
#'
#' @param year Survey year. See [lb_years()].
#' @param format Which published file to use. `"auto"` (the default) tries a
#'   native R file (`.rds`, then `.RData`), then the Stata `.dta` archive, then
#'   the SPSS `.sav`, taking the first that both exists and parses. The SPSS
#'   step is not redundant: the 2024 Stata file is written in a `.dta` format
#'   newer than \pkg{haven} supports, so that wave is only reachable through
#'   its SPSS twin. Set explicitly to `"rds"`, `"rdata"`, `"r"`, `"dta"`,
#'   `"sav"` or `"csv"` to pin one format and fail rather than fall back.
#' @param lang Preferred language for waves published in both, `"eng"` or
#'   `"esp"`. Ignored for waves that ship a single bilingual file.
#' @param force Re-download even if a cached copy exists.
#' @param quiet Suppress progress messages.
#'
#' @return Invisibly, a character vector of the extracted file paths.
#' @seealso [lb_load()] for the usual entry point.
#' @examples
#' \donttest{
#' lb_cache_dir(file.path(tempdir(), "lb_demo"))
#' # Requires internet access to latinobarometro.org
#' try(lb_download(2023))
#' }
#' @export
lb_download <- function(year,
                        format = "auto",
                        lang = c("eng", "esp"),
                        force = FALSE,
                        quiet = FALSE) {
  year <- lb_check_year(year)
  lang <- match.arg(lang)
  pick <- lb_pick_file(year, format = format, lang = lang)

  dest_dir <- file.path(lb_cache_dir(), as.character(year), pick$format)
  dir.create(dest_dir, showWarnings = FALSE, recursive = TRUE)

  existing <- lb_cached_data_files(dest_dir, pick$format)
  if (length(existing) > 0L && !isTRUE(force)) {
    if (!quiet) {
      message("Using cached ", pick$format, " files for wave ", year,
              " (force = TRUE re-downloads).")
    }
    return(invisible(existing))
  }

  zip_path <- file.path(dest_dir, pick$file)
  if (!quiet) message("Downloading ", pick$url, " ...")

  ok <- tryCatch({
    old <- options(timeout = max(600, getOption("timeout", 60)))
    on.exit(options(old), add = TRUE)
    utils::download.file(pick$url, destfile = zip_path,
                         mode = "wb", quiet = quiet)
    TRUE
  }, error = function(e) {
    structure(FALSE, msg = conditionMessage(e))
  }, warning = function(w) {
    structure(FALSE, msg = conditionMessage(w))
  })

  if (!isTRUE(ok) || !file.exists(zip_path) || file.size(zip_path) < 1024) {
    unlink(zip_path)
    stop(
      "Download failed for wave ", year, " (", pick$format, ").\n",
      "URL: ", pick$url, "\n",
      if (!is.null(attr(ok, "msg"))) paste0("Reason: ", attr(ok, "msg"), "\n"),
      "This package downloads only from latinobarometro.org and has no mirror ",
      "(their terms of use prohibit redistribution). Check that the site is ",
      "reachable, then run lb_refresh_urls(", year, ") in case the wave has ",
      "been re-released under a new filename.",
      call. = FALSE
    )
  }

  if (!quiet) message("Unzipping ...")
  extracted <- tryCatch(
    utils::unzip(zip_path, exdir = dest_dir, junkpaths = TRUE),
    error = function(e) {
      stop("Unzip failed for wave ", year, ": ", conditionMessage(e),
           call. = FALSE)
    }
  )

  files <- lb_cached_data_files(dest_dir, pick$format)
  if (length(files) == 0L) {
    stop(
      "The archive for wave ", year, " contained no readable ", pick$format,
      " file.\nExtracted: ", paste(basename(extracted), collapse = ", "),
      call. = FALSE
    )
  }

  if (!quiet) {
    message("Wave ", year, " cached in ", dest_dir, ".")
  }
  invisible(files)
}

# Internal: extensions we can actually read, per manifest format code.
# The "r" archives of 2013-2018 are not self-describing -- some hold .RData,
# some .rds -- so dispatch on the real extension found on disk, not the label.
lb_format_ext <- function(format) {
  switch(format,
    rds   = "rds",
    rdata = c("rdata", "rda"),
    r     = c("rds", "rdata", "rda"),
    dta   = "dta",
    sav   = "sav",
    csv   = "csv",
    stop("Unknown format: ", format, call. = FALSE)
  )
}

lb_cached_data_files <- function(dir, format) {
  if (!dir.exists(dir)) return(character(0))
  all <- list.files(dir, full.names = TRUE, recursive = TRUE)
  ext <- tolower(tools::file_ext(all))
  all[ext %in% lb_format_ext(format)]
}

# Internal: among several candidate data files, prefer an English one and
# never pick a Spanish one when an alternative exists. Mirrors step 3 of the
# Stata program.
lb_choose_file <- function(files, year, quiet = FALSE) {
  if (length(files) == 1L) return(files)

  base <- tolower(basename(files))
  with_year <- files[grepl(as.character(year), base, fixed = TRUE)]
  if (length(with_year) > 0L) {
    files <- with_year
    base  <- tolower(basename(files))
  }

  eng <- files[grepl("eng", base, fixed = TRUE)]
  if (length(eng) > 0L) return(eng[1L])

  neutral <- files[!grepl("esp", base, fixed = TRUE)]
  if (length(neutral) > 0L) return(neutral[1L])

  if (!quiet) {
    message("Only a Spanish-language file is available for wave ", year,
            "; value labels will be in Spanish.")
  }
  files[1L]
}
