## ---------------------------------------------------------------------------
## Staleness check against the live archive.
##
## The manifest is hardcoded because the published filenames are not derivable
## from a pattern. The cost of hardcoding is that a re-release breaks a wave
## until the package is updated -- so this function re-derives the table from
## the live site and reports the difference. Deliberately regex-based rather
## than rvest/xml2: it runs once in a blue moon and is not worth a dependency.
## ---------------------------------------------------------------------------

#' Check the built-in file table against the live Latinobarometro site
#'
#' Latinobarometro re-releases waves under new filenames from time to time
#' (`-v1-0`, `-v20190303`, `-v20250817`), which silently invalidates the
#' package's built-in table. This function scrapes each wave page, extracts the
#' data-file links, and reports what has changed.
#'
#' It does not modify the package. Use it to confirm a download failure is a
#' stale URL rather than a network problem, and send the output along when
#' filing an issue.
#'
#' @param year Optional integer vector of waves to check. Defaults to all.
#' @param quiet Suppress progress messages.
#'
#' @return A data frame with one row per live file, columns `year`, `file`,
#'   `url` and `status`, where `status` is `"unchanged"` for files already in
#'   the built-in table, `"new"` for files found only on the site, and
#'   `"missing"` for entries in the table with no match on the site.
#' @examples
#' \donttest{
#' try(lb_refresh_urls(2024))
#' }
#' @export
lb_refresh_urls <- function(year = NULL, quiet = FALSE) {
  years <- if (is.null(year)) lb_years() else vapply(year, lb_check_year, integer(1))

  live <- do.call(rbind, lapply(years, function(y) {
    if (!quiet) message("Checking wave ", y, " ...")
    files <- lb_scrape_wave(y)
    if (length(files) == 0L) {
      warning("No data files found on the page for wave ", y,
              "; the site layout may have changed.", call. = FALSE)
      return(NULL)
    }
    data.frame(year = y, file = files,
               url = paste0(lb_base_url(), "/LAT-", y, "/", files),
               stringsAsFactors = FALSE)
  }))

  known <- lb_files(years)[, c("year", "file"), drop = FALSE]

  if (is.null(live)) {
    live <- data.frame(year = integer(0), file = character(0),
                       url = character(0), stringsAsFactors = FALSE)
  }

  live$status <- ifelse(
    paste(live$year, live$file) %in% paste(known$year, known$file),
    "unchanged", "new"
  )

  gone <- known[!paste(known$year, known$file) %in%
                  paste(live$year, live$file), , drop = FALSE]
  if (nrow(gone) > 0L) {
    gone$url <- paste0(lb_base_url(), "/LAT-", gone$year, "/", gone$file)
    gone$status <- "missing"
    live <- rbind(live, gone[, names(live), drop = FALSE])
  }

  live <- live[order(live$year, live$file), , drop = FALSE]
  rownames(live) <- NULL

  n_new  <- sum(live$status == "new")
  n_gone <- sum(live$status == "missing")
  if (!quiet) {
    if (n_new == 0L && n_gone == 0L) {
      message("Built-in file table matches the live site.")
    } else {
      message("Built-in file table is out of date: ", n_new, " new file(s), ",
              n_gone, " no longer present. Please open an issue at ",
              "https://github.com/jlopezton/latinobarometro-r/issues")
    }
  }
  live
}

# Internal: pull the data-file basenames out of one wave page.
lb_scrape_wave <- function(year) {
  url <- paste0("https://www.latinobarometro.org/latinobarometro-", year)
  html <- tryCatch(
    paste(readLines(url, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
    error = function(e) {
      stop("Could not read the wave page ", url, ": ", conditionMessage(e),
           call. = FALSE)
    }
  )

  pattern <- paste0("documents/LAT-", year, "/([^\"'>[:space:]]+\\.zip)")
  m <- gregexpr(pattern, html, perl = TRUE)
  hits <- regmatches(html, m)[[1L]]
  if (length(hits) == 0L) return(character(0))
  unique(sub(paste0("^documents/LAT-", year, "/"), "", hits))
}
