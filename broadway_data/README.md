# Broadway Box Office Dashboard

## Summary
Interactive dashboard exploring weekly Broadway box office data (2005–present) —
built for journalists to quickly see which shows are leading, how full houses
are running, and how the market has trended over time (including the 2020
COVID-19 collapse and recovery).

## Status
✅ Live — snapshot view, trend explorer, and leaderboard complete.

## Tools Used
- R, Shiny, bslib, plotly, DT, dplyr, tidyr, scales

## Files
- `clean_data.R` — cleaning pipeline: parses raw fields, flags and corrects
  data-quality issues (closed weeks, missing financials, bad ticket-price
  values), filters to 2005–present, writes `broadway_clean.csv`
- `broadway_clean.csv` — cleaned dataset used by the dashboard (tracked in git;
  the raw source file is not, see `.gitignore`)
- `app.R` — Shiny dashboard: current-week snapshot, top-10 charts, full
  leaderboard, and a trend explorer to compare shows over time

## Data Sources
- Broadway weekly box office grosses, 2005–2025 (public data)

## Run Locally
```r
# from this directory
shiny::runApp()
```
