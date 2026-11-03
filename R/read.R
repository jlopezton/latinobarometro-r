## ---------------------------------------------------------------------------
## Reading a cached wave into R.
##
## Note on Stata parity: steps 4 and 5 of the Stata program (sanitising
## variable names and value-LABEL-SET names that contain periods) have no
## counterpart here. Periods are legal in R names, and haven attaches value
## labels to each column as an attribute rather than through a shared, named
## label set, so the invalid-label-name problem that broke the 2016 and 2017
## waves in Stata simply cannot arise. lb_clean_names() is offered for people
## who want the Stata-style names anyway, but it is off by default.
## ---------------------------------------------------------------------------

#' Read a cached Latinobarometro wave
#'
#' Reads a wave that [lb_download()] has already placed in the cache, choosing
#' the English file when the archive holds more than one language.
#'
#' Column types depend on the source format. Waves read from `.dta` or `.sav`
#' come back as `haven_labelled` columns carrying value labels; waves read from
#' a native `.rds` or `.RData` file come back however Latinobarometro saved
#' them, which is usually plain numeric with factor levels. If you are pooling
#' several waves, pass `format = "dta"` so every wave is read the same way.
#'
#' @inheritParams lb_download
#' @param download Download the wave first if it is not cached.
#'
#' @return A data frame with one row per respondent.
#' @examples
#' \donttest{
#' lb_cache_dir(file.path(tempdir(), "lb_demo"))
#' try(lb_read(2023))
#' }
#' @export
lb_read <- function(year,
                    format = "auto",
                    lang = c("eng", "esp"),
                    download = TRUE,
                    force = FALSE,
                    quiet = FALSE) {
  year  <- lb_check_year(year)
  lang  <- match.arg(lang)
  cands <- lb_pick_files(year, format = format, lang = lang)

  problems <- character(0)

  for (i in seq_len(nrow(cands))) {
    fmt <- cands$format[i]
    dest_dir <- file.path(lb_cache_dir(), as.character(year), fmt)
    files <- lb_cached_data_files(dest_dir, fmt)

    attempt <- tryCatch({
      if (length(files) == 0L) {
        if (!isTRUE(download)) {
          stop("wave is not cached and download = FALSE", call. = FALSE)
        }
        files <- lb_download(year, format = fmt, lang = lang,
                             force = force, quiet = quiet)
      } else if (isTRUE(force)) {
        files <- lb_download(year, format = fmt, lang = lang,
                             force = TRUE, quiet = quiet)
      }

      path <- lb_choose_file(files, year, quiet = quiet)
      if (!quiet) message("Reading ", basename(path))
      list(data = lb_read_file(path), path = path)
    }, error = function(e) e)

    if (!inherits(attempt, "error")) {
      dat <- attempt$data
      attr(dat, "lb_year")   <- year
      attr(dat, "lb_format") <- fmt
      attr(dat, "lb_file")   <- basename(attempt$path)
      return(dat)
    }

    problems <- c(problems, paste0("  ", fmt, ": ", conditionMessage(attempt)))
    if (i < nrow(cands) && !quiet) {
      message("Could not use the ", fmt, " file for wave ", year,
              "; falling back to ", cands$format[i + 1L], ".")
    }
  }

  if (nrow(cands) == 1L) {
    stop("Could not read wave ", year, " as ", cands$format[1L], ".\n",
         paste(problems, collapse = "\n"), "\n",
         lb_read_hint(problems), call. = FALSE)
  }
  stop("Could not read wave ", year, " in any published format.\n",
       paste(problems, collapse = "\n"), "\n",
       lb_read_hint(problems), call. = FALSE)
}

# Internal: turn a reader failure into advice the user can act on.
lb_read_hint <- function(problems) {
  msg <- paste(problems, collapse = " ")
  if (grepl("unsupported features|Invalid file", msg)) {
    return(paste0(
      "Despite its wording, this error usually does not mean the format is ",
      "too new. Some published .dta files in this archive are subtly ",
      "malformed in ways Stata tolerates and haven refuses (a value-label ",
      "table can strand a label past the declared end of its text block). ",
      "With format = \"auto\" the SPSS file is used instead; if you pinned ",
      "format = \"dta\", try format = \"sav\" for the same wave."
    ))
  }
  if (grepl("encoding|byte sequence", msg, ignore.case = TRUE)) {
    return(paste0(
      "An encoding error means the file predates Stata 14 and declares no ",
      "text encoding. This package already tries UTF-8, latin1 and ",
      "windows-1252; if all three failed, please open an issue with the ",
      "wave number."
    ))
  }
  "Run lb_refresh_urls() to check whether the wave has been re-released."
}

# Internal: dispatch on the real file extension.
lb_read_file <- function(path) {
  ext <- tolower(tools::file_ext(path))
  dat <- switch(ext,
    dta   = lb_read_labelled(path, haven::read_dta),
    sav   = lb_read_labelled(path, haven::read_sav),
    rds   = readRDS(path),
    rda   = ,
    rdata = lb_load_rdata(path),
    csv   = utils::read.csv(path, stringsAsFactors = FALSE),
    stop("Do not know how to read a .", ext, " file.", call. = FALSE)
  )

  if (!is.data.frame(dat)) {
    stop("The file ", basename(path), " did not contain a data frame ",
         "(got an object of class ", paste(class(dat), collapse = "/"), ").",
         call. = FALSE)
  }
  dat
}

# Internal: read a .dta or .sav, resolving the text encoding by trial.
#
# Files written before Stata 14 record no encoding, and haven then assumes
# windows-1252. That assumption is wrong for this archive in BOTH directions:
#
#   - The 2024 files are UTF-8. Read as windows-1252 every byte is technically
#     valid, so nothing errors -- the labels just come back as mojibake
#     ("It<U+00E2><U+20AC><U+2122>s enough" instead of "It's enough"). A silent
#     corruption, which is worse than a crash.
#   - Older waves really are latin1, and reading them as UTF-8 fails outright
#     with "invalid byte sequence".
#
# UTF-8 is self-validating, so trying it first is safe and settles both cases:
# a latin1 file will reject it rather than decode wrongly, whereas the reverse
# order silently mangles the UTF-8 files. Non-encoding errors short-circuit,
# so a malformed file is not read three times over.
lb_read_labelled <- function(path, reader) {
  first_error <- NULL

  for (enc in c("UTF-8", "latin1", "windows-1252")) {
    out <- tryCatch(reader(path, encoding = enc), error = function(e) e)

    if (!inherits(out, "error")) {
      if (!identical(enc, "UTF-8")) {
        message("Read ", basename(path), " as ", enc,
                " (the file declares no usable text encoding).")
      }
      return(out)
    }

    if (is.null(first_error)) first_error <- out
    if (!grepl("encoding|byte sequence", conditionMessage(out),
               ignore.case = TRUE)) {
      break
    }
  }
  stop(first_error)
}

# Internal: .RData files hold named objects rather than a single value, and
# Latinobarometro does not use a consistent object name across waves. Load into
# a scratch environment and take the only data frame present.
lb_load_rdata <- function(path) {
  env <- new.env(parent = emptyenv())
  nms <- load(path, envir = env)
  is_df <- vapply(nms, function(n) is.data.frame(get(n, envir = env)),
                  logical(1))
  if (!any(is_df)) {
    stop("No data frame found in ", basename(path), ". Objects present: ",
         paste(nms, collapse = ", "), call. = FALSE)
  }
  if (sum(is_df) > 1L) {
    warning("Several data frames in ", basename(path), " (",
            paste(nms[is_df], collapse = ", "), "); using the first.",
            call. = FALSE)
  }
  get(nms[is_df][1L], envir = env)
}

#' Convert column names to Stata-safe names
#'
#' Replaces every character that is not a letter, digit or underscore with an
#' underscore and lowercases the result, reproducing what the Stata package
#' does with `ustrtoname()`. Useful when you want R and Stata workflows to
#' refer to variables identically; not required to use this package.
#'
#' @param x A data frame, or a character vector of names.
#' @return An object of the same type with cleaned names.
#' @examples
#' lb_clean_names(c("P62N.A", "S1", "idenpa"))
#' @export
lb_clean_names <- function(x) {
  if (is.data.frame(x)) {
    names(x) <- lb_make_name(names(x))
    return(x)
  }
  lb_make_name(x)
}

# Internal: the R equivalent of Stata's subinstr(".","_") + ustrtoname().
lb_make_name <- function(x) {
  x <- gsub("[^A-Za-z0-9_]", "_", x)
  x <- ifelse(grepl("^[0-9]", x), paste0("_", x), x)
  tolower(x)
}
