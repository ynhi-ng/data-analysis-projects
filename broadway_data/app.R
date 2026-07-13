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

## System serif fonts only (no web-font loading) so widgets that measure
## pixel widths on init -- e.g. the ionRangeSlider -- aren't thrown off by a
## late font swap reflowing the page.
nyt_serif <- "Georgia, 'Times New Roman', Times, serif"
plot_font <- list(family = nyt_serif, color = "#121212")

nyt_theme <- bs_theme(
  version = 5,
  base_font = nyt_serif,
  heading_font = nyt_serif,
  bg = "#fdfdfb",
  fg = "#121212",
  primary = "#326891",
  "navbar-bg" = "#fdfdfb",
  "card-border-color" = "#dedad0",
  "card-border-radius" = "0",
  "border-radius" = "0",
  "border-color" = "#121212"
) %>%
  bs_add_rules(sprintf("
    .navbar { border-bottom: 3px double #121212 !important; box-shadow: none; }
    .navbar-brand {
      font-family: %s; font-weight: 700; font-style: italic;
      font-size: 1.8rem; letter-spacing: 0.5px;
    }
    .nav-link { font-family: %s; text-transform: uppercase;
                letter-spacing: 0.08em; font-size: 0.85rem; }
    .card { box-shadow: none; }
    .card-header {
      font-family: %s; font-weight: 700;
      text-transform: uppercase; letter-spacing: 0.06em; font-size: 0.95rem;
      background-color: #fdfdfb; border-bottom: 2px solid #121212;
    }
    .bslib-value-box { border-top: 3px solid #121212 !important; }
    .bslib-value-box .value-box-title {
      font-family: %s; text-transform: uppercase;
      letter-spacing: 0.08em; font-size: 0.8rem; color: #555;
    }
    .bslib-value-box .value-box-value { font-family: %s; }
    table.dataTable { font-family: %s; }
    .irs--shiny .irs-bar, .irs--shiny .irs-single, .irs--shiny .irs-handle {
      background: #326891 !important; border-color: #326891 !important;
    }
  ", nyt_serif, nyt_serif, nyt_serif, nyt_serif, nyt_serif, nyt_serif))


ui <- page_navbar(
  title = "The Broadway Report",
  theme = nyt_theme,

  nav_panel(
    "Current Snapshot",
    card(
      sliderInput("snapshot_range", "Date range",
                  min = min_date, max = latest_week,
                  value = c(latest_week - 365, latest_week),
                  timeFormat = "%b %Y", step = 7, width = "100%")
    ),
    layout_columns(
      col_widths = c(4, 4, 4),
      value_box("Shows running", uiOutput("n_shows_running", inline = TRUE), showcase = NULL),
      value_box("Total gross", uiOutput("total_gross", inline = TRUE), showcase = NULL),
      value_box("Average capacity", uiOutput("avg_capacity", inline = TRUE), showcase = NULL)
    ),
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header(textOutput("top_gross_header")),
        plotlyOutput("top_gross_plot", height = 420)
      ),
      card(
        card_header(textOutput("top_capacity_header")),
        plotlyOutput("top_capacity_plot", height = 420)
      )
    ),
    card(
      card_header(textOutput("leaderboard_header")),
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

  snapshot_range <- reactive({
    req(input$snapshot_range)
    data %>% filter(week_date >= input$snapshot_range[1],
                     week_date <= input$snapshot_range[2])
  })

  snapshot_agg <- reactive({
    snapshot_range() %>%
      group_by(show) %>%
      summarise(
        theater          = theater[which.max(week_date)],
        total_gross      = sum(this_week_gross, na.rm = TRUE),
        avg_ticket_price = mean(avg_ticket_price, na.rm = TRUE),
        total_seats_sold = sum(seats_sold, na.rm = TRUE),
        avg_capacity     = mean(capacity, na.rm = TRUE),
        weeks            = n_distinct(week_date),
        .groups = "drop"
      )
  })

  range_label <- reactive({
    r <- input$snapshot_range
    paste(format(r[1], "%b %d, %Y"), "–", format(r[2], "%b %d, %Y"))
  })

  output$n_shows_running <- renderUI(n_distinct(snapshot_range()$show))
  output$total_gross <- renderUI(money(sum(snapshot_range()$this_week_gross, na.rm = TRUE)))
  output$avg_capacity <- renderUI(paste0(round(mean(snapshot_range()$capacity, na.rm = TRUE), 1), "%"))

  output$top_gross_header <- renderText(paste("Top 10 grossing shows —", range_label()))
  output$top_capacity_header <- renderText(paste("Top 10 shows by capacity % —", range_label()))
  output$leaderboard_header <- renderText(paste("Full leaderboard —", range_label()))

  output$top_gross_plot <- renderPlotly({
    d <- snapshot_agg() %>%
      filter(total_gross > 0) %>%
      slice_max(total_gross, n = 10) %>%
      arrange(total_gross)
    plot_ly(d, x = ~total_gross, y = ~reorder(show, total_gross),
            type = "bar", orientation = "h", marker = list(color = "#326891"),
            hovertemplate = paste0("%{y}<br>", money(1), " %{x:,.0f}<extra></extra>")) %>%
      layout(xaxis = list(title = "Total gross ($)"), yaxis = list(title = ""),
             font = plot_font)
  })

  output$top_capacity_plot <- renderPlotly({
    d <- snapshot_agg() %>%
      filter(!is.na(avg_capacity)) %>%
      slice_max(avg_capacity, n = 10) %>%
      arrange(avg_capacity)
    plot_ly(d, x = ~avg_capacity, y = ~reorder(show, avg_capacity),
            type = "bar", orientation = "h", marker = list(color = "#a91101"),
            hovertemplate = "%{y}<br>%{x:.1f}%<extra></extra>") %>%
      layout(xaxis = list(title = "Average capacity %"), yaxis = list(title = ""),
             font = plot_font)
  })

  output$snapshot_table <- renderDT({
    snapshot_agg() %>%
      transmute(Show = show, Theater = theater,
                `Total Gross` = money(total_gross),
                `Avg Ticket` = money(avg_ticket_price),
                `Total Seats Sold` = comma(total_seats_sold),
                `Avg Capacity %` = round(avg_capacity, 1),
                `Weeks` = weeks) %>%
      arrange(desc(`Total Gross`))
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
                    name = "Broadway-wide average", line = list(color = "#326891"))
    }
    p %>% layout(xaxis = list(title = "Week"), yaxis = list(title = input$metric),
                 font = plot_font)
  })
}

shinyApp(ui, server)
