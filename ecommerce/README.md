# E-Commerce Sales Report

## Summary
Exploratory analysis and customer/product insights for a UK-based online gift
retailer (541,909 raw transactions, Dec 2010–Dec 2011). Cleans the raw
transaction log, then builds customer segmentation (K-means on RFM-style
features) and a product recommender (TF-IDF + cosine similarity on product
descriptions). Findings are published as a static, interactive report.

## Status
Complete

## Tools Used
- Python: pandas, numpy, scikit-learn (KMeans, TF-IDF, cosine similarity), seaborn, matplotlib
- HTML, CSS, JavaScript, Chart.js - for the interactive report

## Files
- `ecommerce_eda.ipynb` — data cleaning, EDA, customer segmentation, and product recommender
- `data.js` — aggregated results exported from the notebook, powers the report's charts
- `index.html`, `style.css`, `script.js` — static interactive report ("The Sales Report")
- `e-commerce_data.csv` — raw transaction data (not tracked in git; see `.gitignore`)

## Data Sources
- Chen, D. (2015). Online Retail [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5BW33.
