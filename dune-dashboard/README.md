# Botto DAO — Dune Dashboard Setup Guide

## Queries Overview

| # | File | Chart Type | Description |
|---|------|-----------|-------------|
| 1 | `01_weekly_art_revenue.sql` | **Stacked Bar** | Weekly art sales by period (Genesis → Collapse Aesthetics) |
| 2 | `02_weekly_total_revenue.sql` | **Bar + Area** | Total revenue, treasury, rewards, cumulative metrics |
| 3 | `03_botto_burns_price.sql` | **Dual-axis Line** | BOTTO burns & token price |
| 4 | `04_pipes_pass_collabs.sql` | **Grouped Bar** | Non-art revenue (Pipes, Access Pass, Collaborations) |
| 5 | `05_summary_counters.sql` | **Counters** | Headline KPIs (total revenue, burns, artworks, etc.) |
| 6 | `06_collaborations_table.sql` | **Table** | Individual collaboration events |

## Setup Instructions

### 1. Create Queries on Dune

1. Go to [dune.com](https://dune.com) → **New Query**
2. Paste each `.sql` file content into a new query
3. Run to verify it works
4. **Save** with a descriptive name (e.g., "Botto - Weekly Art Revenue")
5. Repeat for all 6 queries

### 2. Create Dashboard

1. Go to **New Dashboard**
2. Title: `Botto DAO — Onchain Revenue`

### 3. Add Visualizations

#### Row 1: Counter Widgets (from Query 5)
Create **6 counter widgets** from `05_summary_counters.sql`:
- `grand_total_revenue` → "Total Revenue (ETH)"
- `total_artworks_traded` → "Artworks Traded"
- `current_botto_price` → "BOTTO Price (USD)"
- `total_botto_burnt` → "BOTTO Burned"
- `total_pipe_revenue` → "Pipe Revenue (ETH)"
- `total_pass_revenue` → "Access Pass Revenue (ETH)"

#### Row 2: Weekly Art Revenue (from Query 1)
- Chart type: **Stacked Bar Chart**
- X-axis: `week_end`
- Y-axis: `total_revenue`
- Group by: `period`

#### Row 3: Cumulative Revenue (from Query 2)
- Chart type: **Area Chart**
- X-axis: `week_end`
- Y-axis: `cumulative_revenue`

#### Row 4 (side by side):

**Left: Non-Art Revenue** (from Query 4)
- Chart type: **Stacked Bar**
- X-axis: `week_end`, Y-axis: `revenue`, Group: `source`

**Right: Burns & Price** (from Query 3)
- Chart type: **Line Chart** (dual axis)
- Left Y: `cumulative_botto_burnt`, Right Y: `botto_price`

#### Row 5: Treasury & Rewards (from Query 2)
- Chart type: **Stacked Area**
- X-axis: `week_end`
- Y-axis: `treasury_allocation`, `active_rewards`, `retroactive_rewards`

#### Row 6: Collaborations (from Query 6)
- Chart type: **Table**
- Columns: `mint_date`, `collection`, `link`, `revenue_eth`

## Adding New Periods

When a new Botto period starts:

1. **Determine the contract**: Is it a new contract or a token_id range on existing contract?
2. **Edit queries 1, 2, 5**: Add a `UNION ALL` block in the `all_art_sales` CTE
3. **If new contract**: Add new block like the "2026 CONTRACT" section
4. **If token_id range**: Add to the existing contract's CASE statement

Example for a new period on the 2026 contract:
```sql
-- In the 2026 CONTRACT section, change:
AND token_id >= 1 AND token_id <= 13
-- To:
AND token_id >= 1 AND token_id <= 26
-- And update the CASE to include the new period name
```

## Adding New Collaborations

Edit `06_collaborations_table.sql` and add a new `UNION ALL` block before the closing `) collabs`:
```sql
UNION ALL
SELECT DATE 'YYYY-MM-DD', 'Collaboration Name', 'https://link', revenue_in_eth
```
