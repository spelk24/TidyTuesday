# ------------- #
# --- Setup --- #
# ------------- #

# Load Packages
library(tidyverse)
library(magrittr)
library(httr)
library(jsonlite)
library(dplyr)
library(stringr)
library(janitor)

# nbastatR Function for Accessing the API
.curl_nba_api <- function(url = "https://stats.nba.com/stats/leaguegamelog?Counter=1000&Season=2021-22&Direction=DESC&LeagueID=00&PlayerOrTeam=P&SeasonType=Regular%20Season&Sorter=DATE") {
  
  # API Headers
  headers <- c(
    `Host` = 'stats.nba.com',
    `User-Agent` = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv =72.0) Gecko/20100101 Firefox/72.0',
    `Accept` = 'application/json, text/plain, */*',
    `Accept-Language` = 'en-US,en;q=0.5',
    `Accept-Encoding` = 'gzip, deflate, br',
    `x-nba-stats-origin` = 'stats',
    `x-nba-stats-token` = 'true',
    `Connection` = 'keep-alive',
    `Referer` = 'https =//stats.nba.com/',
    `Pragma` = 'no-cache',
    `Cache-Control` = 'no-cache'
  )
  
  # Request
  res <-GET(
    url,
    add_headers(.headers = headers)
  )
  
  json <- res$content %>%
    rawToChar() %>%
    fromJSON(simplifyVector = T)
  
  return(json)
}

# Contruct URLs -----------------------------------------------------------

# Construct PBP URL
.play_by_play_url <- function(game_id){
  ###
  # Creates NBA API Play-By-Play URL for given Game_id
  #
  # Inputs:
  #   game_id: int/str
  #
  # Returns:
  #   (url): str
  ###
  return(glue::glue("https://stats.nba.com/stats/playbyplayv2/?gameId={game_id}&startPeriod=0&endPeriod=14"))
}

# Construct Boxscore URL
.adv_boxscore_url <-  function(game_id, period){
  ###
  # Creates NBA API Adv Boxscore URL for given Game_id and Period
  #
  # Inputs:
  #   game_id: int/str
  #   period: int
  #
  # Returns:
  #   url:(str)
  #
  ###
  
  # Create start and end times for URL to isolate boxscore for given period
  start <- .calc_time_at_period(period) + 5
  end <- .calc_time_at_period(period + 1) + 5
  
  return(glue::glue("https://stats.nba.com/stats/boxscoreadvancedv2/?gameId={game_id}&startPeriod=0&endPeriod=14&startRange={start}&endRange={end}&rangeType=2"))
}

# Construct Game Logs URL
.game_logs_url <- function(season, league, result_type, season_type, date_from = '', date_to =''){
  ###
  # Creates NBA API Adv Boxscore URL for given Game_id and Period
  #
  # Inputs:
  #   season: int
  #   league: str (NBA/WNBA)
  #   result_type: str (Player, Team)
  #   season_type: str (Regular Season, PlayIn, Playoffs)
  #
  # Returns:
  #   url:(str)
  #
  ###
  
  season_url <- str_c(season-1, str_sub(season,3,4), sep = "-")
  type_url <- case_when(str_to_lower(result_type) == "team" ~ "T",
                        TRUE ~ "P")
  season_type_url <- URLencode(season_type)
  
  if (league %>% str_to_upper() == "WNBA") {
    url <-
      glue::glue(
        "https://stats.nba.com/stats/wnbaseasonstats?College=&Conference=&Country=&DateFrom=&DateTo=&Division=&DraftPick=&DraftYear=&GameScope=&GameSegment=&Height=&LastNGames=0&LeagueID=10&Location=&MeasureType=Base&Month=0&OpponentTeamID=&Outcome=&PORound=&PaceAdjust=&PerMode=PerGame&Period=&PlayerExperience=&PlayerPosition=&PlusMinus=&Rank=&Season={season}&SeasonSegment=&SeasonType={URLencode(season_type)}&ShotClockRange=&StarterBench=&StatCategory=PTS&TeamID=0&VsConference=&VsDivision=&Weight="
      ) %>%
      URLencode() %>%
      as.character()
    
  } else {
    url <-
      glue::glue(
        "https://stats.nba.com/stats/leaguegamelog?Counter=2000&Season={season_url}&Direction=DESC&LeagueID=00&PlayerOrTeam={type_url}&SeasonType={season_type_url}&Sorter=DATE&DateFrom={date_from}&DateTo={date_to}"
      ) %>% as.character()
    
  }
  
  return(url)
}

.team_game_logs_url <- function(season, season_type = "Regular Season" , measure_type = "Base", date_from = '', date_to =''){
  ###
  # Creates NBA API Adv Team Game Logs URL for given Game_id and Period
  #
  # Inputs:
  #   season: int
  #   season_type: str (Regular Season, PlayIn, Playoffs) -- Default = Regular Season
  #   measure_type: str (Base, Advanced, etc) -- Default = Base
  #
  # Returns:
  #   url:(str)
  #
  ###
  
  season_url <- str_c(season-1, str_sub(season,3,4), sep = "-")
  season_type_url  <- URLencode(season_type)
  
  url <- glue::glue("https://stats.nba.com/stats/teamgamelogs?LeagueID=00&MeasureType={measure_type}&PerMode=Totals&Season={season_url}&SeasonType={season_type_url}&DateFrom={date_from}&DateTo={date_to}")
  
  return(url)
  
}

.game_shots_url <- function(season, season_type = "Regular Season", game_id = ""){
  ###
  # Creates NBA API Adv Team Shots URL for given Date Range
  #
  # Inputs:
  #   season: int
  #   game_id: str 
  #   date_from: date/str
  #   date_to: date/str
  #
  # Returns:
  #   url:(str)
  #
  ###
  
  season_url <- str_c(season-1, str_sub(season,3,4), sep = "-")
  season_type_url  <- URLencode(season_type)
  
  url <- glue::glue("https://stats.nba.com/stats/shotchartdetail?SeasonType={season_type_url}&LeagueID=00&Season={season_url}&PlayerID=0&TeamID=0&GameID={game_id}&ContextMeasure=FGA&PlayerPosition=&DateFrom=&DateTo=&GameSegment=&LastNGames=0&Location=&Month=0&OpponentTeamID=0&Outcome=&SeasonSegment=&VSConference=&VSDivision=&RookieYear=&Period=0&StartPeriod=&EndPeriod=&showShots=1")
}

.synergy_playtype_url <- function(season, season_type = "Regular Season", category){
  ###
  # Creates NBA API Synergy Play Type URL for given season and category
  #
  # Inputs:
  #   season: int
  #   season_type: str (Regular Season, PlayIn, Playoffs)
  #   category: str (one of tracking categories found in dropdown at (https://www.nba.com/stats/players/ball-handler))
  #
  # Returns:
  #   url:(str)
  #
  ###
  
  season_url = str_c(season-1, str_sub(season,3,4), sep = "-")
  season_type_url  <- URLencode(season_type)
  
  url <- glue::glue("https://stats.nba.com/stats/synergyplaytypes?LeagueID=00&PerMode=PerGame&PlayType={category}&PlayerOrTeam=P&SeasonType={season_type_url}&SeasonYear={season_url}&TypeGrouping=offensive")
  
}

.tracking_stats_url <- function(season, season_type = "Regular Season", category){
  
  ###
  # Creates NBA API Tracking Stats URL for given season and category
  #
  # Inputs:
  #   season: int
  #   season_type: str (Regular Season, PlayIn, Playoffs)
  #   category: str (one of tracking categories found in dropdown at (https://www.nba.com/stats/players/passing/))
  #
  # Returns:
  #   url:(str)
  #
  ###
  
  season_url = str_c(season-1, str_sub(season,3,4), sep = "-")
  season_type_url  <- URLencode(season_type)
  
  url <- glue::glue("https://stats.nba.com/stats/leaguedashptstats?College=&Conference=&Country=&DateFrom=&DateTo=&Division=&DraftPick=&DraftYear=&GameScope=&Height=&LastNGames=0&LeagueID=00&Location=&Month=0&OpponentTeamID=0&Outcome=&PORound=0&PerMode=Totals&PlayerExperience=&PlayerOrTeam=Player&PlayerPosition=&PtMeasureType={category}&Season={season_url}&SeasonSegment=&SeasonType={season_type_url}&StarterBench=&TeamID=0&VsConference=&VsDivision=&Weight=")
  
}

.team_shots_touch_time_url <- function(season, season_type = "Regular Season", category){
  
  ###
  # Creates NBA API Shots touch time URL for given season and touch category (0-2,3-6, 6+)
  #
  # Inputs:
  #   season: int
  #   season_type: str (Regular Season, PlayIn, Playoffs)
  #   category: str ("quick", "mid", "long")
  #
  # Returns:
  #   url:(str)
  #
  ###
  
  category <- case_when(
    category == "early" ~ "Touch+%3C+2+Seconds",
    category == "mid" ~ "Touch+2-6+Seconds",
    category == "long" ~ "Touch+6%2B+Seconds",
    TRUE ~ ""
  )
  
  season_url = str_c(season-1, str_sub(season,3,4), sep = "-")
  season_type_url  <- URLencode(season_type)
  
  url <- glue::glue("https://stats.nba.com/stats/leaguedashteamptshot?CloseDefDistRange=&Conference=&DateFrom=&DateTo=&Division=&DribbleRange=&GameSegment=&GeneralRange=&LastNGames=&LeagueID=00&Location=&Month=&OpponentTeamID=&Outcome=&PORound=&PerMode=Totals&Period=&Season={season_url}&SeasonSegment=&SeasonType={season_type_url}&ShotClockRange=&ShotDistRange=&TeamID=&TouchTimeRange={category}&VsConference=&VsDivision=")
  
}

# Schedule/Time Functions -----------------------------------------------------------------------------------------------------------------------

get_todays_nba_schedule <- function(){
  ###
  #Returns NBA Schedule dataframe for today's system date
  ###
  headers <- c(
    `Connection` = 'keep-alive',
    `Accept` = 'application/json, text/plain, */*',
    `x-nba-stats-token` = 'true',
    `X-NewRelic-ID` = 'VQECWF5UChAHUlNTBwgBVw==',
    `User-Agent` = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.87 Safari/537.36',
    `x-nba-stats-origin` = 'stats',
    `Sec-Fetch-Site` = 'same-origin',
    `Sec-Fetch-Mode` = 'cors',
    `Referer` = 'https://stats.nba.com/',
    `Accept-Encoding` = 'gzip, deflate, br',
    `Accept-Language` = 'en-US,en;q=0.9'
  )
  
  day = Sys.Date()
  
  url <- paste0("https://stats.nba.com/stats/scoreboardv3?GameDate=",day,"&LeagueID=00")
  res <- GET(url = url, add_headers(.headers=headers))
  json_resp <- fromJSON(content(res, "text")) 
  
  date <- json_resp[["scoreboard"]][["gameDate"]]
  
  todays_games <- data.frame(
      home_team = str_to_title(json_resp[["scoreboard"]][["games"]][["homeTeam"]][["teamSlug"]]),
      away_team = str_to_title(json_resp[["scoreboard"]][["games"]][["awayTeam"]][["teamSlug"]]),
      date = date,
      time = as.POSIXct(json_resp[["scoreboard"]][["games"]][["gameEt"]], format = "%Y-%m-%dT%H:%M:%OS")
    ) %>% 
    rowwise() %>% 
    #Get sorted alphabetical matchup to inner join on dk_get_player_props
    mutate(matchup = paste(sort(trimws(strsplit(paste0(home_team, "-", away_team), '-')[[1]])), collapse='-'))
  
  return(todays_games)
}

# API Dataframe Construnction ---------------------------------------------

get_nba_pbp <- function(game_id){
  ###
  # Calls API for PBP data and puts into dataframe format
  #
  # Inputs:
  #   game_id: int/str
  #
  # Returns:
  #   pbp_df: dataframe
  #
  ###
  
  # Call API
  pbp_json = .curl_nba_api(.play_by_play_url(game_id))
  # Isolate Column Names
  pbp_names = pbp_json$resultSets$headers[[1]]
  # Isolate Data
  pbp_df <- pbp_json$resultSets$rowSet[[1]] %>% 
    # Put into Dataframe
    data.frame(stringsAsFactors = F) %>% 
    as_tibble() %>% 
    # Add Column Names
    set_names(pbp_names)
  
  return(pbp_df)
}

get_nba_adv_boxscore_qtr <- function(game_id, period){
  ###
  # Calls API for Adv Boxscore data and puts into dataframe format
  #
  # Inputs:
  #   game_id: int/str
  #   period: int
  #
  # Returns:
  #   boxscore_df: dataframe
  #
  ###
  
  # Call API
  boxscore_json <- .curl_nba_api(.adv_boxscore_url(game_id, period))
  # Isolate Column Names
  boxscore_names <- boxscore_json$resultSets$headers[[1]]
  # Isolate Data
  boxscore_df <- boxscore_json$resultSets$rowSet[[1]] %>%  
    # Put into Dataframe
    data.frame(stringsAsFactors = F) %>% 
    as_tibble() %>% 
    # Add Column Name
    set_names(boxscore_names)
  
  return(boxscore_df)
}

get_team_game_logs <- function(season, season_type = "Regular Season" , measure_type = "Base", date_from = '', date_to = ''){
  ###
  # Calls API for Adv Boxscore data and puts into dataframe format
  #
  # Inputs:
  #   season: int/str
  #   season_type: str (Default: Regular Season)
  #   measure_type: str (Default: Base)
  #
  # Returns:
  #   game_log_df: dataframe
  #
  ###
  if(date_from != "" & str_detect(date_from, '\\d{2}\\/\\d{2}\\/\\d{4}', negate = T)){
    stop("Dates must be in the format MM/DD/YYYY")
  }
  if(date_to != "" & str_detect(date_to, '\\d{2}\\/\\d{2}\\/\\d{4}', negate = T)){
    stop("Dates must be in the format MM/DD/YYYY")
  }
  
  
  # Call API
  game_log_json <- .curl_nba_api(.team_game_logs_url(season, season_type, measure_type, date_from, date_to))
  # Isolate Column Names
  game_log_names <- game_log_json$resultSets$headers[[1]]
  # Isolate Data
  game_log_df <- game_log_json$resultSets$rowSet[[1]] %>%  
    # Put into Dataframe
    data.frame(stringsAsFactors = F) %>% 
    as_tibble() %>% 
    # Add Column Name
    set_names(game_log_names)
  
  return(game_log_df)
}

get_game_logs <- function(season, league = "NBA", result_type = "Player", season_type = "Regular Season", date_from = '', date_to = ''){
  ###
  # Calls API for Basic Game Logs data and puts into dataframe format
  #
  # Inputs:
  #   season: int/str
  #   league: str (Default: NBA)
  #   season_type: str (Default: Regular Season)
  #   result_type: str (Default: Player)
  #
  # Returns:
  #   game_log_df: dataframe
  #
  ###
  if(date_from != "" & str_detect(date_from, '\\d{2}-\\d{2}-\\d{4}', negate = T)){
    stop("Dates must be in the format MM-DD-YYYY")
  }
  if(date_to != "" & str_detect(date_to, '\\d{2}-\\d{2}-\\d{4}', negate = T)){
    stop("Dates must be in the format MM-DD-YYYY")
  }
  
  # Call API
  game_log_json <- .curl_nba_api(.game_logs_url(season, league, result_type, season_type, date_from, date_to))
  # Isolate Column Names
  game_log_names <- game_log_json$resultSets$headers[[1]]
  # Isolate Data
  game_log_df <- game_log_json$resultSets$rowSet[[1]] %>%  
    # Put into Dataframe
    data.frame(stringsAsFactors = F) %>% 
    as_tibble() %>% 
    # Add Column Name
    set_names(game_log_names)
  
  return(game_log_df)
}

get_game_shots <- function(season, season_type = "Regular Season", game_id){
  ###
  # Calls API for shots data and puts into dataframe format
  #
  # Inputs:
  #   season: int/str
  #   season_type: str (Default: Regular Season)
  #   game_id: str
  #
  # Returns:
  #   shots_df: dataframe
  #
  ###
  
  # Call API
  shots_json = .curl_nba_api(.game_shots_url(season, season_type, game_id))
  # Isolate Column Names
  shots_names = shots_json$resultSets$headers[[1]]
  # Isolate Data
  shots_df <- shots_json$resultSets$rowSet[[1]] %>% 
    # Put into Dataframe
    data.frame(stringsAsFactors = F) %>% 
    as_tibble() %>% 
    # Add Column Names
    set_names(shots_names)
  
  return(shots_df)
}

get_synergy_stats <- function(season, season_type = "Regular Season", category){
  ###
  # Calls API for Synergy data and puts into dataframe format
  #
  # Inputs:
  #   season: int/str
  #   season_type: str (Default: Regular Season)
  #   category: str (one of tracking categories found in dropdown at (https://www.nba.com/stats/players/ball-handler/))
  #
  # Returns:
  #   synergy: dataframe
  #
  ###
  
  #Call API
  res <- .curl_nba_api(.synergy_playtype_url(season, season_type, category))
  #Isolate Data
  synergy <- res[["resultSets"]][["rowSet"]][[1]] %>% 
    as.data.frame()
  #Add column names to Data
  colnames(synergy) <-  res[["resultSets"]][["headers"]][[1]]
  #Clean up column names
  synergy <- synergy %>% 
    janitor::clean_names()
  
  return(synergy)
}

get_tracking_stats <- function(season, season_type = "Regular Season", category){
  
  ###
  # Calls API for Tracking data and puts into dataframe format
  #
  # Inputs:
  #   season: int/str
  #   season_type: str (Default: Regular Season)
  #   category: str (one of tracking categories found in dropdown at (https://www.nba.com/stats/players/passing/))
  #
  # Returns:
  #   tracking_df: dataframe
  #
  ###
  
  #Call API
  res <- .curl_nba_api(.tracking_stats_url(season, season_type, category))
  #Isolate Data
  tracking_df <- res[["resultSets"]][["rowSet"]][[1]] %>% 
    as.data.frame()
  #Add column names to Data
  colnames(tracking_df) <-  res[["resultSets"]][["headers"]][[1]]
  #Clean up column names
  tracking_df <- tracking_df %>% 
    janitor::clean_names()
  
  return(tracking_df)
  
}

get_team_shots_by_touch_time <- function(season, season_type = "Regular Season", category){
  
  ###
  # Calls API for Team Touch data for a given category
  #
  # Inputs:
  #   season: int/str
  #   season_type: str (Default: Regular Season)
  #   category: str (early, mid, long)
  #
  # Returns:
  #   touch_df: dataframe
  #
  ###
  
  #Call API
  res <- .curl_nba_api(.team_shots_touch_time_url(season, season_type, category))
  #Isolate Data
  touch_df <- res[["resultSets"]][["rowSet"]][[1]] %>% 
    as.data.frame()
  #Add column names to Data
  colnames(touch_df) <-  res[["resultSets"]][["headers"]][[1]]
  #Clean up column names
  touch_df <- touch_df %>% 
    janitor::clean_names()
  
  return(touch_df)
  
}
