### Update master schedule
suppressMessages(suppressWarnings(library(dplyr)))
suppressMessages(suppressWarnings(library(gamezoneR)))
suppressMessages(suppressWarnings(library(readr)))
suppressMessages(suppressWarnings(library(stringr)))
suppressMessages(suppressWarnings(library(purrr)))
suppressMessages(suppressWarnings(library(optparse)))

option_list <- list(
  make_option("--season", type = "character", default = NULL,
              help = "Season to scrape"),
  make_option("--postseason", type = "logical", default = FALSE,
              help = "Only update schedule for postseason games?")
)
opt <- parse_args(OptionParser(option_list=option_list))
# Rscript R/master_schedule.R (--season "2018-19")

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

cat("Starting master schedule scrape for", sn, "...\n")

# Path to file
path <- stringr::str_sub(sn, start = 3) %>%
  stringr::str_replace("-", "_") %>%
  paste0("data/schedules/master_schedule_", ., ".csv")

# If not just a March Madness update, re-scrape all schedules
if (isFALSE(opt$postseason)) {
  # Get team schedules for each season
  team_schedules <- tidyr::crossing(team = gamezoneR::mbb_team_info$game_zone,
                                    season = c(sn))

  # Get all team schedule games
  all_games <- purrr::map_dfr(seq_len(nrow(team_schedules)), function(index) {

    team_season <- team_schedules %>%
      dplyr::slice(index)

    gamezoneR::gamezone_mbb_team_schedule(team_season$team, season = team_season$season)
  }) %>%
    dplyr::distinct(.data$game_id, .keep_all = T) %>%
    dplyr::arrange(.data$game_date)
} else {
  all_games <- readr::read_csv(path, col_types = readr::cols())
}

# Get potential postseason dates
march_madness <- dplyr::tibble(year = as.numeric(paste0("20", stringr::str_sub(sn, start = 6)))) %>%
  dplyr::mutate(begin = as.Date(paste0(year, "-03-08"), format = "%Y-%m-%d"),
                end = as.Date(paste0(year, "-04-15"), format = "%Y-%m-%d"),
                date = purrr::map2(begin, end, ~ seq(.x, .y, by = 1))) %>%
  tidyr::unnest(date) %>%
  dplyr::select(-c(begin, end))

# Get March Madness schedules
mm_games <- purrr::map_df(march_madness$date, gamezoneR::gamezone_mbb_master_schedule, ranked_games = FALSE) %>%
  dplyr::distinct(game_id, .keep_all = TRUE)
mm_games_ranked <- purrr::map_df(march_madness$date, gamezoneR::gamezone_mbb_master_schedule, ranked_games = TRUE)

# If there are games, bind them with regular season
if (nrow(mm_games) > 0) {

  mm_games <- mm_games %>%
    dplyr::filter(!game_id %in% mm_games_ranked$game_id) %>%
    dplyr::bind_rows(mm_games_ranked) %>%
    dplyr::distinct(.data$game_id, .keep_all = TRUE) %>%
    dplyr::arrange(.data$game_date)

  # Only keep postseason games not already in regular season schedule
  mm <- mm_games %>%
    dplyr::anti_join(all_games %>%
                       dplyr::select(game_date, game_id),
                     by = c("game_date", "game_id"))

  # Bind all games together
  all_games <- dplyr::bind_rows(all_games, mm) %>%
    dplyr::distinct(.data$game_id, .keep_all = TRUE) %>%
    dplyr::arrange(.data$game_date)
} else {
  cat("No postseason games scheduled for", sn, ".\n")
}

cat("Writing", nrow(all_games), "games to", path, "...\n")

# Write .csv of games
readr::write_csv(all_games, path)

# all_games %>% group_by(season) %>% summarise(max = max(game_date))

cat("Completed master schedule scrape for", sn, ".\n")

