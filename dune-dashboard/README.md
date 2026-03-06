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
| 7 | `07_collection_counts.sql` | **Table** | Count of artworks per collection/period |
| 8 | `08_snapshot_governance.sql` | **Table + Bar** | Snapshot governance proposals & monthly aggregates |
| 9 | `09_token_supply_breakdown.sql` | **Stacked Area** | BOTTO token supply by category (burned, staked, LP, etc.) |
| 10 | `10_treasury_balance.sql` | **Stacked Area + Line** | Treasury ETH balance breakdown & BOTTO holdings |
| 11 | `11_staking_metrics.sql` | **Area + Line + Bar** | Staking volume, total staked, new/unique stakers |
| 12 | `12_rewards_distribution.sql` | **Bar + Area + Line** | ETH rewards distributed, USD value, claimers |
| 13 | `13_dex_volume.sql` | **Bar + Line** | DEX trading volume (Ethereum + Base) |
| 14 | `14_art_sales_performance.sql` | **Table + Bar** | Per-period art sales stats with period-over-period comparison |

## Setup Instructions

### 1. Create Queries on Dune

1. Go to [dune.com](https://dune.com) → **New Query**
2. Paste each `.sql` file content into a new query
3. Run to verify it works
4. **Save** with a descriptive name (e.g., "Botto - Weekly Art Revenue")
5. Repeat for all 14 queries

### 2. Create Dashboard

1. Go to **New Dashboard**
2. Title: `Botto DAO — Onchain Revenue`

### 3. Add Visualizations

#### Row 1: Counter Widgets (from Query 5)
Create **6 counter widgets** from `05_summary_counters.sql`:
- `grand_total_revenue` → "Total Revenue (ETH)"
- `artworks_sold` → "1/1 Artworks Sold"
- `current_botto_price` → "BOTTO Price (USD)"
- `total_botto_burnt` → "BOTTO Burned"
- `total_pipe_revenue` → "Pipe Revenue (ETH)"
- `non_one_of_one_sold` → "Non-1/1 Artworks (Pipes/Collabs)"

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

#### Row 7: Collection Counts (from Query 7)
- Chart type: **Table**
- Columns: `Collection`, `Type`, `Count`
- Sort by `Type` desc, then `Collection` asc

#### Row 8: Snapshot Governance (from Query 8)

**Table view:**
- Chart type: **Table**
- Columns: `proposal_date`, `title`, `voter_count`, `total_voting_power`, `approval_pct`, `quorum_met`, `result`

**Bar chart (monthly aggregates):**
- Chart type: **Bar Chart**
- X-axis: `proposal_month`
- Y-axis: `monthly_proposal_count`
- Secondary Y: `monthly_avg_voters`

#### Row 9: Token Supply Breakdown (from Query 9)
- Chart type: **Stacked Area**
- X-axis: `week_end`
- Y-series: `burned`, `gov_staking`, `uni_v2_lp`, `uni_v3_lp`, `rewards_wallet`, `liquidity_mining`, `circulating`

#### Row 10 (side by side):

**Left: Treasury ETH Composition** (from Query 10)
- Chart type: **Stacked Area**
- X-axis: `week_end`
- Y-series: `eth_balance`, `weth_balance`, `steth_balance`, `wsteth_balance`

**Right: Treasury USD Value** (from Query 10)
- Chart type: **Line**
- X-axis: `week_end`, Y-axis: `total_eth_usd`

#### Row 11: Staking Metrics (from Query 11)

**Left: Staking Volume**
- Chart type: **Bar**
- X-axis: `week_end`
- Y-axis: `weekly_staked` (green), `weekly_unstaked` (red)

**Center: Total Staked**
- Chart type: **Area**
- X-axis: `week_end`, Y-axis: `total_staked`

**Right: Staker Counts**
- Chart type: **Line**
- X-axis: `week_end`, Y-axis: `unique_stakers`, `new_stakers`

#### Row 12: Rewards Distribution (from Query 12)
- Chart type: **Bar** for `weekly_eth_distributed`
- Overlay **Area** for `cumulative_eth_distributed`
- Overlay **Line** for `unique_claimers` (right axis)
- X-axis: `week_end`

#### Row 13: DEX Volume (from Query 13)

**Stacked Bar:**
- Chart type: **Stacked Bar**
- X-axis: `week_end`
- Y-axis: `eth_volume_usd`, `base_volume_usd`

**Cumulative Line:**
- Chart type: **Line**
- X-axis: `week_end`, Y-axis: `cumulative_volume_usd`

#### Row 14: Art Sales Performance (from Query 14)
- Chart type: **Table**
- Columns: `period`, `total_sales`, `primary_count`, `secondary_count`, `total_revenue`, `avg_price`, `min_price`, `max_price`, `primary_pct`, `revenue_change_pct`
- Sort by `sort_order` asc

**Bar chart:**
- Chart type: **Bar**
- X-axis: `period` (sorted by `sort_order`)
- Y-axis: `total_revenue`

## Adding New Periods

When a new Botto period starts:

1. **Determine the contract**: Is it a new contract or a token_id range on existing contract?
2. **Edit queries 1, 2, 5, 14**: Add a `UNION ALL` block in the `all_art_sales` CTE
3. **If new contract**: Add new block like the "2026 CONTRACT" section
4. **If token_id range**: Add to the existing contract's CASE statement
5. **Update query 14**: Add the new period to the `period_order` VALUES list

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

Also update `02_weekly_total_revenue.sql`, `04_pipes_pass_collabs.sql`, `05_summary_counters.sql`, and `07_collection_counts.sql` with the corresponding collaboration data.

## Key Addresses

| Label | Address |
|-------|---------|
| BOTTO Token (Ethereum) | `0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba` |
| BOTTO Token (Base) | `0x24914cb6bd01e6a0cf2a9c0478e33c25926e6a0c` |
| Treasury | `0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49` |
| Gov Staking | `0x19cd3998f106ecc40ee7668c19c47e18b491e8a6` |
| Rewards Wallet | `0x93298241417a63469b6f8f080b4878749acb4c47` |
| Uniswap V2 LP | `0x9ff68f61ca5eb0c6606dc517a9d44001e564bb66` |
| Uniswap V3 LP | `0xd60dc6571e477fb2d96df02efd5fba9c54a4e998` |
| Liquidity Mining | `0xf8515cae6915838543bcd7756f39268ce8f853fd` |
| Burn Address | `0x000000000000000000000000000000000000dead` |
