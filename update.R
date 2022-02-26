### Update master schedule/play-by-play and push to GitHub repo
suppressMessages(suppressWarnings(library(gamezoneR)))
# suppressMessages(suppressWarnings(library(git2r)))
suppressMessages(suppressWarnings(library(glue)))
suppressMessages(suppressWarnings(library(optparse)))

option_list <- list(
  make_option("--season", type = "character", default = NULL,
              help = "Season to scrape"),
  make_option("--update_schedule", type = "logical", default = TRUE,
              help = "Re-scrape master schedule?"),
  make_option("--postseason", type = "logical", default = FALSE,
              help = "Postseason schedule update only?"),
  make_option("--update_pbp", type = "logical", default = TRUE,
              help = "Re-scrape play-by-play?")
)
opt <- parse_args(OptionParser(option_list=option_list))
# Rscript R/update.R (--season "2018-19") --update_schedule FALSE

# Default to current season
if (is.null(opt$season)) {
  sn <- gamezoneR:::available_seasons() %>%
    dplyr::last()
} else {
  sn <- opt$season
}

# Check if season is valid
if (!sn %in% gamezoneR:::available_seasons()) {
  cat("Not a valid season to scrape... Quitting R session")
  quit(status = 49)
}

# Set working directory
# setwd("/Users/JackLich/Desktop/RStudio/gamezoneR-data")

# Run update to master schedule
if (isTRUE(opt$update_schedule)) {
  # Rscript R/master_schedule.R (--season "2018-19")
  system(paste0("Rscript R/master_schedule.R --season ", sn, " --postseason ", opt$postseason))
}

# Run update to play-by-play
if (isTRUE(opt$update_pbp)) {
  # Rscript R/play_by_play.R (--season "2018-19")
  system(paste0("Rscript R/play_by_play.R --season ", sn))
}

cat("Completed data update to remote repo for", sn, ".\n")


### Perhaps scrape schedule daily?
# last_scraped_date <- gamezoneR::load_gamezone_pbp(seasons = "2020-21") %>%
#   dplyr::distinct(date) %>%
#   dplyr::filter(date == max(date)) %>%
#   dplyr::pull(date)
#
# cat("Most recent scraped game in", sn, "is from", as.character(last_scraped_date), ".\n")
#
# dates_to_scrape <- as.Date((last_scraped_date-1):Sys.Date(), origin = "1970-01-01")
#
# gamezoneR::gamezone_mbb_master_schedule(dates_to_scrape[1])

# pbp <- gamezoneR::load_gamezone_pbp(seasons = "2021-22")
#
# pbp %>%
#   distinct(game_id) %>%
#   nrow()
#   filter(!is.na(loc_x)) %>%
#   nrow()


### Deprecated
#
# # Set up connection to repository folder
# repo <- git2r::repository('./')
# cred <- git2r::cred_token()
# version <- "0.1.1"
#
# ### Update schedule
# git2r::add(repo, glue::glue("data/schedules/*"))
# # Check status
# status <- git2r::status()
#
# if (!rlang::is_empty(status$staged)) {
#   # Commit staged files
#   git2r::commit(repo, message = glue::glue("Updated master schedule {Sys.time()} using gamezoneR version {version}"))
#   # Pull repo
#   git2r::pull(repo, credentials = cred)
#   # Push commit
#   git2r::push(repo, credentials = git2r::cred_user_pass('JackLich10', Sys.getenv("GITHUB_PAT")))
# } else {
#   cat("Nothing to commit in data/schedules.\n")
# }
#
# ### Update games
# git2r::add(repo, glue::glue("data/play_by_play/*"))
# # Check status
# status <- git2r::status()
#
# if (!rlang::is_empty(status$staged)) {
#   # Commit staged files
#   git2r::commit(repo, message = glue::glue("Updated play-by-plays {Sys.time()} using gamezoneR version {version}"))
#   # Pull repo
#   git2r::pull(repo, credentials = cred)
#   # Push commit
#   git2r::push(repo, credentials = git2r::cred_user_pass('JackLich10', Sys.getenv("GITHUB_PAT"))) # push commit
# } else {
#   cat("Nothing to commit in data/play_by_play.\n")
# }
