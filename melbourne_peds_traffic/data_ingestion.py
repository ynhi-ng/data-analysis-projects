"""
ingest.py

Pulls hourly pedestrian count data from the City of Melbourne Open Data API
(Pedestrian Counting System dataset) for a chosen set of sensors and date range.

Implements the algorithm we agreed on:
- One filtered query per sensor (keeps each query's row count well under
  the API's 9,999-row cap)
- Pagination in steps of 100 (the confirmed max page size) within each sensor
- Retry with backoff on failed requests
- Raw results saved locally before any cleaning, so later steps never need
  to re-hit the API

Usage:
    python ingest.py
"""

import os
import time
import requests
import pandas as pd

# ---------------------------------------------------------------------------
# Configuration - EDIT THESE VALUES
# ---------------------------------------------------------------------------
DATASET_ID = "pedestrian-counting-system-monthly-counts-per-hour"
BASE_URL = (
    f"https://data.melbourne.vic.gov.au/api/explore/v2.1/catalog/"
    f"datasets/{DATASET_ID}/records"
)

# Replace with your chosen sensor location_id values from the Map tab
LOCATION_IDS = [69, 84, 19]  

START_DATE = "2026-01-20"  # 6 months back from 2026-07-20

PAGE_SIZE = 100  # confirmed max "limit" per request
REQUEST_DELAY_SECONDS = 0.3  # politeness pause between requests
MAX_RETRIES = 3
RETRY_BACKOFF_SECONDS = 2

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_PATH = os.path.join(SCRIPT_DIR, "data", "pedestrian_raw.parquet")


def fetch_sensor_data(location_id: int) -> list:
    """
    Pull all records for a single sensor (location_id) from START_DATE
    to the most recent available date, handling pagination.
    """
    where_clause = f'sensing_date >= "{START_DATE}" and location_id = {location_id}'
    all_rows = []
    offset = 0

    while True:
        params = {
            "where": where_clause,
            "limit": PAGE_SIZE,
            "offset": offset,
        }

        rows = _get_page_with_retries(params)

        if rows is None:
            # All retries failed for this page - stop pulling this sensor
            # rather than losing already-collected rows for it.
            print(
                f"[location_id={location_id}] Failed to fetch page at "
                f"offset={offset}. Stopping this sensor."
            )
            break

        all_rows.extend(rows)

        if len(rows) < PAGE_SIZE:
            # Fewer rows than a full page means this was the last page.
            break

        offset += PAGE_SIZE
        time.sleep(REQUEST_DELAY_SECONDS)

    print(f"[location_id={location_id}] Retrieved {len(all_rows)} rows.")
    return all_rows


def _get_page_with_retries(params: dict):
    """
    Request a single page of results, retrying on failure.
    Returns the list of result rows, or None if all retries failed.
    """
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = requests.get(BASE_URL, params=params, timeout=30)
            response.raise_for_status()
            data = response.json()
            return data.get("results", [])
        except requests.exceptions.RequestException as e:
            print(f"Attempt {attempt}/{MAX_RETRIES} failed: {e}")
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_BACKOFF_SECONDS)
    return None


def main():
    combined_rows = []

    for location_id in LOCATION_IDS:
        sensor_rows = fetch_sensor_data(location_id)
        combined_rows.extend(sensor_rows)

    if not combined_rows:
        print("No data retrieved. Exiting without saving.")
        return

    df = pd.DataFrame(combined_rows)

    # Sanity check summary - compare against expected ~4,368 rows/sensor
    # for a 6-month pull, per our earlier estimate.
    print("\n--- Summary ---")
    print(f"Total rows retrieved: {len(df)}")
    print(df.groupby("location_id").size())

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    df.to_parquet(OUTPUT_PATH, index=False)
    print(f"\nSaved raw data to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()