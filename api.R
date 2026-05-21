library(plumber)
library(jsonlite)

.state <- new.env(parent = emptyenv())
.state$df <- NULL
.state$col_map <- list()

`%||%` <- function(a, b) if (!is.null(a)) a else b

#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  if (req$REQUEST_METHOD == "OPTIONS") { res$status <- 200; return(list()) }
  plumber::forward()
}

pick_col <- function(df, candidates) {
  nms <- names(df)
  hit <- candidates[tolower(candidates) %in% tolower(nms)]
  if (length(hit) > 0) return(nms[match(tolower(hit[1]), tolower(nms))])
  NULL
}

infer_mapping <- function(df) {
  list(
    lat = pick_col(df, c("lat", "latitude", "y")),
    lon = pick_col(df, c("lon", "lng", "long", "longitude", "x")),
    id  = pick_col(df, c("id", "bird_band", "animal_id", "track_id", "band")),
    dt  = pick_col(df, c("dt", "dt_r", "datetime", "timestamp", "time", "date_time")),
    color_by = pick_col(df, c("sex", "category", "group", "class", "type"))
  )
}

col <- function(name) {
  if (!is.null(.state$col_map[[name]]) && nzchar(.state$col_map[[name]])) {
    return(.state$col_map[[name]])
  }
  if (!is.null(.state$df)) {
    m <- infer_mapping(.state$df)
    if (!is.null(m[[name]]) && nzchar(m[[name]])) return(m[[name]])
  }
  name
}

safe_num <- function(x) suppressWarnings(as.numeric(x))

parse_dt <- function(x) {
  if (inherits(x, c("POSIXct", "POSIXlt"))) return(as.POSIXct(x, tz = "UTC"))
  if (inherits(x, "Date")) return(as.POSIXct(x, tz = "UTC"))
  formats <- c(
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d %H:%M",
    "%d-%m-%Y %H:%M:%S",
    "%d-%m-%Y %H:%M",
    "%d/%m/%Y %H:%M:%S",
    "%d/%m/%Y %H:%M",
    "%Y-%m-%dT%H:%M:%SZ",
    "%Y-%m-%dT%H:%M:%S",
    "%Y-%m-%d"
  )
  x_chr <- as.character(x)
  for (fmt in formats) {
    parsed <- suppressWarnings(as.POSIXct(x_chr, format = fmt, tz = "UTC"))
    if (!all(is.na(parsed))) return(parsed)
  }
  suppressWarnings(as.POSIXct(x_chr, tz = "UTC"))
}

format_dt <- function(x) {
  ifelse(is.na(x), "", format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"))
}

load_file <- function(raw_data, ext) {
  tmp <- tempfile(fileext = paste0(".", ext))
  writeBin(raw_data, tmp)
  on.exit(unlink(tmp), add = TRUE)
  if (ext == "rds") {
    df <- readRDS(tmp)
    if (!is.data.frame(df)) stop("RDS file does not contain a data frame.")
  } else {
    df <- read.csv(tmp, stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
    if (nrow(df) == 0) df <- read.csv(tmp, stringsAsFactors = FALSE, check.names = FALSE)
  }
  df
}

parse_date_cols <- function(df) {
  for (cn in names(df)) {
    if (inherits(df[[cn]], c("POSIXct", "POSIXlt", "Date"))) {
      df[[cn]] <- as.POSIXct(df[[cn]], tz = "UTC")
    } else if (grepl("date|time|^dt$|_dt$|^dt_|timestamp", cn, ignore.case = TRUE)) {
      parsed <- parse_dt(df[[cn]])
      if (!all(is.na(parsed))) df[[cn]] <- parsed
    }
  }
  df
}

split_animals <- function(a) {
  if (is.null(a)) return(NULL)
  if (length(a) == 1) strsplit(a, ",")[[1]] else a
}

filtered_data <- function(animals = NULL, date_from = NULL, date_to = NULL) {
  d <- .state$df
  if (is.null(d)) return(NULL)
  dt_col <- col("dt")
  id_col <- col("id")
  if (!is.null(animals) && length(animals) > 0 && any(nzchar(animals))) {
    d <- d[d[[id_col]] %in% animals, , drop = FALSE]
  }
  if (!is.null(date_from) && nzchar(date_from)) {
    d <- d[!is.na(d[[dt_col]]) & d[[dt_col]] >= as.POSIXct(date_from, tz = "UTC"), , drop = FALSE]
  }
  if (!is.null(date_to) && nzchar(date_to)) {
    d <- d[!is.na(d[[dt_col]]) & d[[dt_col]] <= as.POSIXct(paste(date_to, "23:59:59"), tz = "UTC"), , drop = FALSE]
  }
  d
}

#* @post /upload
#* @parser multi
function(req, res) {
  tryCatch({
    files <- req$body
    if (length(files) == 0) stop("No file received.")
    
    file <- files[[1]]
    raw_data <- file$value
    fname <- file$filename %||% "file.csv"
    ext <- tolower(tools::file_ext(fname))
    if (!ext %in% c("csv", "rds")) ext <- "csv"
    
    message("Uploading file: ", fname, " (", length(raw_data), " bytes)")
    
    df <- load_file(raw_data, ext)
    df <- parse_date_cols(df)
    
    .state$df <- df
    .state$col_map <- infer_mapping(df)
    
    message("Loaded: ", nrow(df), " rows, columns: ", paste(names(df), collapse = ", "))
    
    list(
      success = TRUE,
      rows = nrow(df),
      columns = names(df),
      mapping = .state$col_map,
      col_types = vapply(df, function(x) class(x)[1], character(1))
    )
  }, error = function(e) {
    message("Upload error: ", conditionMessage(e))
    res$status <- 400
    list(success = FALSE, error = conditionMessage(e))
  })
}

#* @post /columns
#* @parser json
function(req, res) {
  message("Columns POST received: ", paste(names(req$body), collapse = ", "))
  mapping <- req$body
  .state$col_map <- mapping
  df <- .state$df
  dt_col <- mapping[["dt"]]
  if (!is.null(df) && !is.null(dt_col) && nzchar(dt_col) && !inherits(df[[dt_col]], "POSIXct")) {
    df[[dt_col]] <- parse_dt(df[[dt_col]])
    .state$df <- df
  }
  list(success = TRUE, mapping = mapping)
}

#* @get /meta
function(res) {
  if (is.null(.state$df)) { res$status <- 400; return(list(error = "No data loaded")) }
  d <- .state$df
  id_col <- col("id")
  dt_col <- col("dt")
  animals <- sort(unique(as.character(d[[id_col]])))
  dt_ok <- d[[dt_col]][!is.na(d[[dt_col]])]
  list(
    animals = animals,
    date_min = if (length(dt_ok)) format(min(dt_ok), "%Y-%m-%d") else "",
    date_max = if (length(dt_ok)) format(max(dt_ok), "%Y-%m-%d") else "",
    total_rows = nrow(d)
  )
}

#* @get /points
function(req, res, animals = NULL, date_from = NULL, date_to = NULL, max_points = 25000) {
  if (is.null(.state$df)) { res$status <- 400; return(list(error = "No data loaded")) }
  animals <- split_animals(animals)
  d <- filtered_data(animals, date_from, date_to)
  if (is.null(d) || nrow(d) == 0) return(list(points = list(), total = 0))
  
  lat_col <- col("lat")
  lon_col <- col("lon")
  id_col  <- col("id")
  dt_col  <- col("dt")
  mapping <- .state$col_map
  
  if (any(vapply(list(lat_col, lon_col, id_col, dt_col), is.null, logical(1)))) {
    res$status <- 400
    return(list(error = "Could not infer required columns."))
  }
  
  d <- d[order(d[[dt_col]], na.last = TRUE), , drop = FALSE]
  
  max_points <- as.integer(max_points)
  if (nrow(d) > max_points) {
    ids <- unique(d[[id_col]])
    per_animal <- max(1L, floor(max_points / length(ids)))
    d <- do.call(rbind, lapply(ids, function(aid) {
      sub <- d[d[[id_col]] == aid, , drop = FALSE]
      idx <- unique(round(seq(1, nrow(sub), length.out = min(nrow(sub), per_animal))))
      sub[idx, , drop = FALSE]
    }))
  }
  
  out <- data.frame(
    lat = safe_num(d[[lat_col]]),
    lon = safe_num(d[[lon_col]]),
    id  = as.character(d[[id_col]]),
    dt  = format_dt(d[[dt_col]]),
    stringsAsFactors = FALSE
  )
  extra_cols <- unname(unlist(mapping))
  extra_cols <- extra_cols[!is.na(extra_cols) & nzchar(extra_cols)]
  extra_cols <- setdiff(extra_cols, c(lat_col, lon_col, id_col, dt_col))
  extra_cols <- head(unique(extra_cols), 8)
  
  for (ec in extra_cols) {
    if (ec %in% names(d)) out[[ec]] <- as.character(d[[ec]])
  }

  ok <- !is.na(out$lat) & !is.na(out$lon) & nzchar(out$dt)
  out <- out[ok, , drop = FALSE]
  
  list(points = out, total = nrow(d))
}

#* @get /stats
function(req, res, animals = NULL, date_from = NULL, date_to = NULL) {
  if (is.null(.state$df)) { res$status <- 400; return(list(error = "No data loaded")) }
  animals <- split_animals(animals)
  d <- filtered_data(animals, date_from, date_to)
  if (is.null(d) || nrow(d) == 0) return(list(animals = list()))
  
  lat_col <- col("lat")
  lon_col <- col("lon")
  id_col  <- col("id")
  dt_col  <- col("dt")
  
  haversine_km <- function(lat1, lon1, lat2, lon2) {
    R <- 6371
    dLat <- (lat2 - lat1) * pi / 180
    dLon <- (lon2 - lon1) * pi / 180
    a <- sin(dLat/2)^2 + cos(lat1*pi/180) * cos(lat2*pi/180) * sin(dLon/2)^2
    R * 2 * atan2(sqrt(a), sqrt(1-a))
  }
  
  stats_list <- lapply(unique(d[[id_col]]), function(aid) {
    sub <- d[d[[id_col]] == aid, , drop = FALSE]
    sub <- sub[order(sub[[dt_col]], na.last = TRUE), , drop = FALSE]
    n <- nrow(sub)
    lats <- safe_num(sub[[lat_col]])
    lons <- safe_num(sub[[lon_col]])
    dts <- sub[[dt_col]]
    dist_km <- 0
    speeds <- numeric(0)
    if (n > 1) {
      dists <- mapply(haversine_km, head(lats,-1), head(lons,-1), tail(lats,-1), tail(lons,-1))
      dist_km <- sum(dists, na.rm = TRUE)
      dt_hrs <- as.numeric(difftime(tail(dts,-1), head(dts,-1), units = "hours"))
      dt_hrs[dt_hrs <= 0] <- NA
      speeds <- dists / dt_hrs
    }
    dts_ok <- dts[!is.na(dts)]
    tbl <- table(format(dts_ok, "%Y-%m-%d"))
    list(
      id = as.character(aid),
      n_points = n,
      total_km = round(dist_km, 2),
      mean_speed_kmh = if (length(speeds)) round(mean(speeds, na.rm = TRUE), 2) else NULL,
      max_speed_kmh = if (length(speeds)) round(max(speeds, na.rm = TRUE), 2) else NULL,
      date_first = if (length(dts_ok)) format(min(dts_ok), "%Y-%m-%d") else "",
      date_last = if (length(dts_ok)) format(max(dts_ok), "%Y-%m-%d") else "",
      daily = list(dates = names(tbl), counts = as.integer(tbl))
    )
  })
  list(animals = stats_list)
}

#* @get /export
#* @serializer text
function(req, res, animals = NULL, date_from = NULL, date_to = NULL) {
  if (is.null(.state$df)) { res$status <- 400; return("No data loaded") }
  animals <- split_animals(animals)
  d <- filtered_data(animals, date_from, date_to)
  if (is.null(d) || nrow(d) == 0) return("")
  res$setHeader("Content-Type", "text/csv")
  res$setHeader("Content-Disposition", 'attachment; filename="tracking_export.csv"')
  tmp <- tempfile()
  write.csv(d, tmp, row.names = FALSE)
  paste(readLines(tmp), collapse = "\n")
}