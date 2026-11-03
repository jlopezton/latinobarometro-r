##### Sending the latinobarometro R file to CRAN

install.packages(c("devtools","roxygen2"))
devtools::document()
devtools::test()
devtools::test(filter = "network")


# As Cran
devtools::check(args = "--as-cran")
available::available("latinobarometro")   # confirm the name properly
devtools::check_win_devel() 

# Test the downloads of Latinobarometro (24 downloads)

lb_cache_dir(persist = TRUE)
for (y in lb_years()) {
  r <- try(lb_load(y, harmonize = TRUE, quiet = TRUE), silent = TRUE)
  cat(y, if (inherits(r, "try-error")) "FAIL" else
    paste(nrow(r), "rows,", attr(r, "lb_format")), "\n")
}


# The rds files are having problems

sapply(c(2011, 2016, 2018, 2020), function(y)
  length(unique(lb_load(y, quiet = TRUE)$X_001)))

# Encoding might be wrong

for (y in c(2000, 2005, 2010, 2011)) {
  d <- lb_load(y, quiet = TRUE)
  labs <- unlist(lapply(d, function(x) names(attr(x, "labels"))))
  cat(y, ":", grep("é|ó|ú|ñ|â€|Ã", labs, value = TRUE)[1:3], "\n")
}


