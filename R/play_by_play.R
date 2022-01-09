### Update play-by-plays
suppressMessages(suppressWarnings(library(dplyr)))
suppressMessages(suppressWarnings(library(gamezoneR)))
suppressMessages(suppressWarnings(library(readr)))
suppressMessages(suppressWarnings(library(stringr)))
suppressMessages(suppressWarnings(library(purrr)))
suppressMessages(suppressWarnings(library(optparse)))

option_list <- list(
  make_option("--season", type = "character", default = NULL,
              help = "Season to scrape")
)
opt <- parse_args(OptionParser(option_list=option_list))
# Rscript R/play_by_play.R (--season "2018-19")

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

cat("Starting play-by-play scrape for", sn, "...\n")

# Need to update .rds flag
need_update <- 0

# Path of master schedule
path <- stringr::str_sub(sn, start = 3) %>%
  stringr::str_replace("-", "_") %>%
  paste0("data/schedules/master_schedule_", ., ".csv")

# Read in master schedule
master_schedule <- readr::read_csv(path, col_types = readr::cols())

# Read in known missing games from GameZone
missing <- readr::read_csv("data/play_by_play/missing/missing_pbp.csv", col_types = readr::cols())

# All completed games
completed_games <- list.files(paste0("data/play_by_play/", sn, "/")) %>%
  stringr::str_remove("\\.csv$") %>%
  as.numeric()

# Do not try to scrape known missing games
master_schedule <- master_schedule %>%
  dplyr::anti_join(missing,
                   by = "game_id") %>%
  # Do not try to scrape games that have not been played yet or have already been scraped
  dplyr::filter(game_date <= Sys.Date()+1,
                !game_id %in% completed_games)

cat("Starting play-by-play scrape of", nrow(master_schedule), "games...\n")

purrr::walk2(master_schedule$season, master_schedule$game_id, function(season, gid) {

  # To test
  # season <- master_schedule$season[1]
  # gid <- master_schedule$game_id[1]
  # gid <- 2400761

  # Path to play-by-play
  pbp_path <- paste0("data/play_by_play/", season, "/", gid, ".csv")

  # Check if play-by-play already on github repository
  # pbp <- try(readr::read_csv(paste0("https://raw.githubusercontent.com/JackLich10/gamezoneR-data/main/", pbp_path),
  #                            col_types = readr::cols()),
  #            silent = T)
  # if ("try-error" %in% class(pbp))

  if (!file.exists(file.path(pbp_path))) {
    # If at least one game is scraped, need update to .rds
    need_update <- 1

    pbp <- gamezoneR::gamezone_mbb_pbp(gid, sub_parse = TRUE)

    if (!is.null(pbp)) {
      # Create play_by_play directory
      ifelse(!dir.exists(file.path("data/play_by_play")),
             dir.create(file.path("data/play_by_play")), FALSE)

      # Create play-by-play/season directory
      ifelse(!dir.exists(file.path(paste0("data/play_by_play/", unique(pbp$season)))),
             dir.create(file.path(paste0("data/play_by_play/", unique(pbp$season)))), FALSE)

      # Write .csv of play-by-play
      readr::write_csv(pbp, pbp_path)
    } else {
      # Find date of missing game
      date <- master_schedule %>%
        dplyr::filter(game_id == gid) %>%
        dplyr::select(game_date) %>%
        dplyr::pull(game_date)

      # If date of game is greater than or equal to the current day, maybe it has not been played yet
      if (!(date >= Sys.Date())) {
        # Create missing play-by-play directory
        ifelse(!dir.exists(file.path("data/play_by_play/missing")),
               dir.create(file.path("data/play_by_play/missing")), FALSE)

        # Create play-by-play/season directory
        ifelse(!file.exists(file.path(paste0("data/play_by_play/missing/missing_pbp.csv"))),
               readr::write_csv(dplyr::tibble(game_id = gid), "data/play_by_play/missing/missing_pbp.csv"),
               readr::write_csv(readr::read_csv("data/play_by_play/missing/missing_pbp.csv",
                                                col_types = readr::cols()) %>%
                                  dplyr::bind_rows(dplyr::tibble(game_id = gid)) %>%
                                  dplyr::distinct(),
                                "data/play_by_play/missing/missing_pbp.csv"))
      } else {
        cat("GameID", gid, "might not have been played yet.\n")
      }
    }
  } else {
    cat("Already have GameID", gid, ".\n")
  }
  cat("Next\n")
})

cat("Completed play-by-play scrape for", sn, ".\n")

# if (need_update == 1) {
  save_pbp_rds <- function(season) {
    pbp <- dir(paste0("data/play_by_play/", season, "/"), pattern = ".*.csv", full.names = TRUE) %>%
      purrr::set_names(.) %>%
      purrr::map_df(~ readr::read_csv(., col_types = readr::cols())) %>%
      dplyr::select(-dplyr::any_of(c(
        "home_6", "home_7", "home_8", "home_9", "home_10",
        "away_6", "away_7", "away_8", "away_9", "away_10"
      )))

    saveRDS(pbp, paste0("data/play_by_play/rds/pbp_", stringr::str_remove(season, "-"), ".rds"))
  }

  cat("Saving", sn, "play-by-play of as a .rds...\n")

  purrr::walk(c(sn), save_pbp_rds)

  cat("Completed save to .rds for", sn, ".\n")
# } else {
  # cat("No need to update play-by-play .rds for", sn, ".\n")
# }

