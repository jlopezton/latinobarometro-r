## ---------------------------------------------------------------------------
## Cache location.
## 
## The original Stata version of this package downloaded the files into the 
## user's home stata dir (the files are small ~3MB).
## CRAN policy forbids writing to the user's home filespace without explicit
## consent, so the default cache is a session-scoped tempdir(). Users opt into
## a persistent cache once, with lb_cache_dir(persist = TRUE), which stores
## files under tools::R_user_dir("latinobarometro", "cache"). This is the
## R-side equivalent of the Stata package's cache() option.
## ---------------------------------------------------------------------------

lb_cache_env <- new.env(parent = emptyenv())

#' Get or set the download cache directory
#'
#' Downloaded survey archives, the time-series crosswalk and World Bank
#' population data are cached so that a wave is fetched from
#' Latinobarometro at most once.
#'
#' By default the cache lives in the session temporary directory and is
#' discarded when R exits. Call `lb_cache_dir(persist = TRUE)` once to store it
#' under [tools::R_user_dir()] instead, so waves survive across sessions. You
#' can also point at any directory with `path`, or set the
#' `LATINOBAROMETRO_CACHE` environment variable.
#'
#' @param path Optional directory to use as the cache. Created if needed.
#' @param persist Logical. If `TRUE`, use the persistent user cache directory
#'   returned by `tools::R_user_dir("latinobarometro", "cache")`.
#'
#' @return The cache directory path, invisibly when setting.
#' @examples
#' # Session-scoped by default
#' lb_cache_dir()
#'
#' # Use a directory of your choosing
#' lb_cache_dir(file.path(tempdir(), "lb_demo"))
#' @export
lb_cache_dir <- function(path = NULL, persist = FALSE) {
  if (isTRUE(persist) && is.null(path)) {
    path <- tools::R_user_dir("latinobarometro", "cache")
  }
  if (!is.null(path)) {
    dir.create(path, showWarnings = FALSE, recursive = TRUE)
    lb_cache_env$dir <- normalizePath(path, mustWork = TRUE)
    return(invisible(lb_cache_env$dir))
  }

  if (!is.null(lb_cache_env$dir)) return(lb_cache_env$dir)

  env <- Sys.getenv("LATINOBAROMETRO_CACHE", "")
  if (nzchar(env)) {
    dir.create(env, showWarnings = FALSE, recursive = TRUE)
    lb_cache_env$dir <- normalizePath(env, mustWork = TRUE)
    return(lb_cache_env$dir)
  }

  # An already-established persistent cache is honoured without asking again.
  user_dir <- tools::R_user_dir("latinobarometro", "cache")
  if (dir.exists(user_dir)) {
    lb_cache_env$dir <- normalizePath(user_dir, mustWork = TRUE)
    return(lb_cache_env$dir)
  }

  tmp <- file.path(tempdir(), "latinobarometro_cache")
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
  lb_cache_env$dir <- normalizePath(tmp, mustWork = TRUE)
  if (is.null(lb_cache_env$warned)) {
    message(
      "Caching downloads in a temporary directory for this session only.\n",
      "Call lb_cache_dir(persist = TRUE) once to keep waves between sessions."
    )
    lb_cache_env$warned <- TRUE
  }
  lb_cache_env$dir
}

#' Remove cached Latinobarometro downloads
#'
#' @param year Optional integer vector of waves to clear. Defaults to the whole
#'   cache, including the crosswalk and population files.
#' @return Invisibly, the paths removed.
#' @examples
#' lb_cache_dir(file.path(tempdir(), "lb_demo"))
#' lb_clear_cache()
#' @export
lb_clear_cache <- function(year = NULL) {
  root <- lb_cache_dir()
  targets <- if (is.null(year)) {
    list.files(root, full.names = TRUE)
  } else {
    file.path(root, as.character(as.integer(year)))
  }
  unlink(targets, recursive = TRUE, force = TRUE)
  invisible(targets)
}
