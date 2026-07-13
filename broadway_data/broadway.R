

# load library

required_packages = c("shiny", "plotly", "dplyr", "tidyr", "DT",
                      "lubridate", "htmltools", "bslib", "scales")
missing_packages = required_packages[
  !(required_packages %in% installed.packages()[, "Package"])]
if (length(missing_packages) > 0) {
  message("Installing: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, dependencies = TRUE)
}
invisible(lapply(required_packages, library, character.only = TRUE))

# load data
data = read.csv("broadway_data.csv",stringsAsFactors = FALSE)
# lower attributes
names(data) <- tolower(names(data))
# convert to numeric
data <- data %>%
  mutate(
    this.week.gross = as.numeric(gsub("[\\$,]", "", this.week.gross)), #strip the $ and ,
    potential.gross = as.numeric(gsub("[\\$,]", "", potential.gross)),
    avg.ticket.price = as.numeric(gsub("[\\$,]", "", avg.ticket.price)),
    top.ticket.price  = as.numeric(gsub("[\\$,]", "", top.ticket.price)),
    seats.sold  = as.numeric(gsub(",", "", seats.sold)),
    seats.in.theater = as.numeric(gsub(",", "", seats.in.theater)),
    capacity..  = as.numeric(gsub("%", "", capacity..))
  )

# re check
str(data[, c("this.week.gross", "potential.gross", "avg.ticket.price",
             "top.ticket.price", "seats.sold", "seats.in.theater", "capacity..")])

## Data Quality check 

#1.Flag closed weeks, missing financials, and scan for other abnormalities 

data <- data %>%
  mutate(
    is_closed_week          = performances == 0,
    has_missing_financials  = this.week.gross == 0 & performances > 0,
    flag_sold_no_gross      = this.week.gross == 0 & seats.sold > 0,
    flag_gross_no_sold      = this.week.gross > 0  & seats.sold == 0,
    flag_capacity_over_100  = capacity.. > 100,
    flag_capacity_zero_sold = capacity.. == 0 & seats.sold > 0,
    flag_price_zero_neg     = avg.ticket.price <= 0,
    flag_top_lt_avg         = top.ticket.price < avg.ticket.price,
    flag_theater_zero_cap   = seats.in.theater == 0 & performances > 0
  )

# Summary counts for each flag
flag_cols <- c("is_closed_week", "has_missing_financials", "flag_sold_no_gross",
               "flag_gross_no_sold", "flag_capacity_over_100", "flag_capacity_zero_sold",
               "flag_price_zero_neg", "flag_top_lt_avg", "flag_theater_zero_cap")

data %>%
  summarise(across(all_of(flag_cols), ~sum(.x, na.rm = TRUE)))

# Which shows are affected by each flag (inspect before deciding how to treat them)
for (f in flag_cols) {
  cat("\n---", f, "---\n")
  print(
    data %>%
      filter(.data[[f]]) %>%
      distinct(show, theater) %>%
      head(10) #take 10 first records only
  )
}

# 
cat("\nNumber of distinct shows")
n_distinct(data$show)

#2. Convert column names to snake_case 

names(data) <- names(data) %>%
  gsub("\\.+", "_", .) %>%   # collapse one-or-more dots into a single underscore
  gsub("_$", "", .)          # remove a trailing underscore, if any

names(data)

#3. Cross check for data quality 

# check 1 : total row counts 
data %>% summarise(across(all_of(flag_cols), ~sum(.x, na.rm = TRUE)))

# check 2: for ticket price < 0 
data %>%
  filter(flag_price_zero_neg) %>%
  mutate(year = year(as.Date(week_date))) %>%
  count(year) %>%
  arrange(year)

# check 3 : capacity > 100
data %>%
  filter(flag_capacity_over_100) %>%
  summarise(
    min_capacity = min(capacity, na.rm = TRUE),
    median_capacity = median(capacity, na.rm = TRUE),
    max_capacity = max(capacity, na.rm = TRUE),
    n_rows = n()
  )

# distribution detail - how many rows fall into which range
data %>%
  filter(flag_capacity_over_100) %>%
  mutate(capacity_band = cut(capacity, breaks = c(100, 110, 125, 150, 200, Inf))) %>%
  count(capacity_band)


# check for top price < average price
data %>%
  filter(flag_top_lt_avg) %>%
  mutate(price_gap = avg_ticket_price - top_ticket_price) %>%
  select(show, theater, week_date, avg_ticket_price, top_ticket_price, price_gap) %>%
  arrange(desc(price_gap)) %>%
  head(15)

# check seat = 0 but there is actual performance
data %>%
  filter(flag_capacity_zero_sold) %>%
  as.data.frame()



# check : how much of flag_top_lt_avg is "top price = 0" 

data %>%
  filter(flag_top_lt_avg) %>%
  mutate(top_is_zero = top_ticket_price == 0) %>%
  count(top_is_zero)

# for the non-zero group, look at actual gap sizes 
data %>%
  filter(flag_top_lt_avg, top_ticket_price > 0) %>%
  mutate(price_gap = avg_ticket_price - top_ticket_price) %>%
  select(show, theater, week_date, avg_ticket_price, top_ticket_price, price_gap) %>%
  arrange(desc(price_gap)) %>%
  head(15)

#4. Data correctness

# is_close_week : keep 
# has_missing_financials : set gross, seats, capacity to NA, data might not reflect 
## the actual state of the show
# flag_sold_no_gross/ flag_cross_no_sold : no action
# flag_capacity_over 100 :keep
# flag_capacity_zero_sold : keep 
# flag_price_zero_neg : keep
# flag_top_lt_avg with top_ticket_price = 0  : set top_ticket_price to NA when top_ticket_price = 0
# flag_top_lt_avg with top_ticket_price > 0 : keep
# flag_theater_zero_cap : keep 

# Transformation: apply NA corrections 

data <- data %>%
  mutate(
    # blank out financials for rows with no usable financial data
    this_week_gross  = if_else(has_missing_financials, NA_real_, this_week_gross),
    seats_sold       = if_else(has_missing_financials, NA_real_, seats_sold),
    seats_in_theater = if_else(has_missing_financials, NA_real_, seats_in_theater),
    capacity         = if_else(has_missing_financials, NA_real_, capacity),
    
    # blank out top_ticket_price where it's 0 due to a data gap,
    # not a real $0 price 
    top_ticket_price = if_else(flag_top_lt_avg & top_ticket_price == 0,
                               NA_real_, top_ticket_price)
  )

# sanity check
data %>%
  filter(has_missing_financials) %>%
  select(show, week_date, this_week_gross, seats_sold, capacity) %>%
  distinct(show) 

data %>%
  filter(flag_top_lt_avg, top_ticket_price == 0) %>%
  nrow()   

#5. Filter date:the post-2000 

data_post2000 <- data %>%
  filter(week_date >= as.Date("2000-01-01"))

nrow(data_post2000)
n_distinct(data_post2000$show)


#6. Cross check for theater name 
