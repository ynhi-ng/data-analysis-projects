## Clean weekly Broadway box office data and export a tidy CSV for the dashboard.
## Raw source: broadway_data.csv (not tracked in git, see .gitignore)
## Output: broadway_clean.csv (tracked, used by app.R)

library(dplyr)
library(lubridate)

data <- read.csv("broadway_data.csv", stringsAsFactors = FALSE)
names(data) <- tolower(names(data))

data <- data %>%
  mutate(
    this.week.gross   = as.numeric(gsub("[\\$,]", "", this.week.gross)),
    potential.gross   = as.numeric(gsub("[\\$,]", "", potential.gross)),
    avg.ticket.price  = as.numeric(gsub("[\\$,]", "", avg.ticket.price)),
    top.ticket.price  = as.numeric(gsub("[\\$,]", "", top.ticket.price)),
    seats.sold        = as.numeric(gsub(",", "", seats.sold)),
    seats.in.theater  = as.numeric(gsub(",", "", seats.in.theater)),
    capacity..        = as.numeric(gsub("%", "", capacity..)),
    week.date         = as.Date(week.date)
  )

## 1. Flag closed weeks, missing financials, and other abnormalities
data <- data %>%
  mutate(
    is_closed_week          = performances == 0,
    has_missing_financials  = this.week.gross == 0 & performances > 0,
    flag_capacity_over_100  = capacity.. > 100,
    flag_capacity_zero_sold = capacity.. == 0 & seats.sold > 0,
    flag_price_zero_neg     = avg.ticket.price <= 0,
    flag_top_lt_avg         = top.ticket.price < avg.ticket.price,
    flag_theater_zero_cap   = seats.in.theater == 0 & performances > 0
  )

## 2. snake_case column names
names(data) <- names(data) %>%
  gsub("\\.+", "_", .) %>%
  gsub("_$", "", .)

## 3. Apply NA corrections for known data gaps
data <- data %>%
  mutate(
    this_week_gross   = if_else(has_missing_financials, NA_real_, this_week_gross),
    seats_sold        = if_else(has_missing_financials, NA_real_, seats_sold),
    seats_in_theater  = if_else(has_missing_financials, NA_real_, seats_in_theater),
    capacity          = if_else(has_missing_financials, NA_real_, capacity),
    top_ticket_price  = if_else(flag_top_lt_avg & top_ticket_price == 0,
                                 NA_real_, top_ticket_price)
  )

## 4. Restrict to 2005-present (recent-enough era for a "current state" story,
##    while still showing multi-year trend)
data_clean <- data %>%
  filter(week_date >= as.Date("2005-01-01"), !is_closed_week)

## 5. Keep only the columns the dashboard needs
data_clean <- data_clean %>%
  select(
    show, theater, week_date,
    this_week_gross, potential_gross, avg_ticket_price, top_ticket_price,
    seats_sold, seats_in_theater, performances, previews, capacity
  ) %>%
  arrange(week_date, show)

cat("Rows after cleaning:", nrow(data_clean), "\n")
cat("Distinct shows:", n_distinct(data_clean$show), "\n")
cat("Date range:", format(min(data_clean$week_date)), "to", format(max(data_clean$week_date)), "\n")

write.csv(data_clean, "broadway_clean.csv", row.names = FALSE)
cat("Wrote broadway_clean.csv\n")
