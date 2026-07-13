## Broadway Box Office Dashboard
## Audience: journalists exploring the current state of Broadway (2005-present)
## Data: broadway_clean.csv (produced by clean_data.R)

library(shiny)
library(bslib)
library(dplyr)
library(tidyr)
library(plotly)
library(DT)
library(scales)

data <- read.csv("broadway_clean.csv", stringsAsFactors = FALSE) %>%
  mutate(week_date = as.Date(week_date))

latest_week <- max(data$week_date)
min_date <- min(data$week_date)
show_choices <- sort(unique(data$show))

money <- function(x) dollar(x, accuracy = 1)

ui <- page_navbar(
  title = "Broadway Box Office",
  theme = bs_theme(bootswatch = "flatly"),

  nav_panel(
    "Current Snapshot",
    layout_columns(
      col_widths = c(4, 4, 4),
      value_box("Week of", format(latest_week, "%b %d, %Y"), showcase = NULL),
      value_box("Shows running", uiOutput("n_shows_running", inline = TRUE), showcase = NULL),
      value_box("Total gross this week", uiOutput("total_gross", inline = TRUE), showcase = NULL)
    ),
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Top 10 grossing shows — this week"),
        plotlyOutput("top_gross_plot", height = 420)
      ),
      card(
        card_header("Top 10 shows by capacity % — this week"),
        plotlyOutput("top_capacity_plot", height = 420)
      )
    ),
    card(
      card_header("Full leaderboard — this week"),
      DTOutput("snapshot_table")
    )
  ),

  nav_panel(
    "Trends Over Time",
    layout_sidebar(
      sidebar = sidebar(
        selectizeInput("shows", "Compare shows (leave blank for Broadway-wide average)",
                        choices = show_choices, multiple = TRUE,
                        options = list(maxItems = 6)),
        dateRangeInput("date_range", "Date range",
                        start = min_date, end = latest_week,
                        min = min_date, max = latest_week),
        selectInput("metric", "Metric",
                    choices = c("Weekly gross" = "this_week_gross",
                                "Average ticket price" = "avg_ticket_price",
                                "Capacity %" = "capacity",
                                "Seats sold" = "seats_sold"))
      ),
      card(
        card_header("Trend"),
        plotlyOutput("trend_plot", height = 500)
      )
    )
  ),

  nav_panel(
    "About",
    card(
      markdown(
        "**Data**: Weekly Broadway box office grosses, 2005–present.

        **Cleaning notes**: closed weeks and rows with unusable financial data
        (zero gross despite performances that week) are excluded. See
        `clean_data.R` for the full cleaning pipeline and
        [project README](README.md) for data sources.

        Built with R Shiny, plotly, and bslib."
      )
    )
  )
)

server <- function(input, output, session) {

  snapshot <- data %>% filter(week_date == latest_week)

  output$n_shows_running <- renderUI(n_distinct(snapshot$show))
  output$total_gross <- renderUI(money(sum(snapshot$this_week_gross, na.rm = TRUE)))

  output$top_gross_plot <- renderPlotly({
    d <- snapshot %>%
      filter(!is.na(this_week_gross)) %>%
      slice_max(this_week_gross, n = 10) %>%
      arrange(this_week_gross)
    plot_ly(d, x = ~this_week_gross, y = ~reorder(show, this_week_gross),
            type = "bar", orientation = "h",
            hovertemplate = paste0("%{y}<br>", money(1), " %{x:,.0f}<extra></extra>")) %>%
      layout(xaxis = list(title = "This week's gross ($)"), yaxis = list(title = ""))
  })

  output$top_capacity_plot <- renderPlotly({
    d <- snapshot %>%
      filter(!is.na(capacity)) %>%
      slice_max(capacity, n = 10) %>%
      arrange(capacity)
    plot_ly(d, x = ~capacity, y = ~reorder(show, capacity),
            type = "bar", orientation = "h",
            hovertemplate = "%{y}<br>%{x:.1f}%<extra></extra>") %>%
      layout(xaxis = list(title = "Capacity %"), yaxis = list(title = ""))
  })

  output$snapshot_table <- renderDT({
    snapshot %>%
      transmute(Show = show, Theater = theater,
                `Gross` = money(this_week_gross),
                `Avg Ticket` = money(avg_ticket_price),
                `Seats Sold` = comma(seats_sold),
                `Capacity %` = round(capacity, 1),
                `Performances` = performances) %>%
      arrange(desc(`Gross`))
  }, options = list(pageLength = 10), rownames = FALSE)

  output$trend_plot <- renderPlotly({
    d <- data %>% filter(week_date >= input$date_range[1], week_date <= input$date_range[2])

    if (length(input$shows) > 0) {
      d <- d %>% filter(show %in% input$shows)
      p <- plot_ly(d, x = ~week_date, y = ~.data[[input$metric]], color = ~show,
                    type = "scatter", mode = "lines")
    } else {
      d <- d %>%
        group_by(week_date) %>%
        summarise(value = mean(.data[[input$metric]], na.rm = TRUE), .groups = "drop")
      p <- plot_ly(d, x = ~week_date, y = ~value, type = "scatter", mode = "lines",
                    name = "Broadway-wide average")
    }
    p %>% layout(xaxis = list(title = "Week"), yaxis = list(title = input$metric))
  })
}

shinyApp(ui, server)
