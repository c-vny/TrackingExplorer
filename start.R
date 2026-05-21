# start.R  — launch the Animal Tracking Explorer
# Usage: Rscript start.R

cat("Installing required packages if needed...\n")
pkgs <- c("plumber", "jsonlite")
invisible(lapply(pkgs, function(p) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p, repos = "https://cloud.r-project.org")
}))

library(plumber)
cat("Starting Animal Tracking API on http://localhost:8080\n")
cat("Open index.html in your browser to use the interface.\n\n")

pr("api.R") |> pr_run(host = "0.0.0.0", port = 8080)


