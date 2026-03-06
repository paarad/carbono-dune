# Botto DAO — Dune Dashboard Visualization Guide

## Query 01 — `01_weekly_art_revenue.sql`
**Save as:** "Botto - Weekly Art Revenue"

| Viz # | Type | Title | Settings |
|-------|------|-------|----------|
| 1 | **Bar Chart** | Weekly Art Revenue by Period | X: `week_end` · Y: `total_revenue` · Group by: `period` · Stacking: **stacked** |

---

## Query 02 — `02_weekly_total_revenue.sql`
**Save as:** "Botto - Weekly Total Revenue"

| Viz # | Type | Title | Settings |
|-------|------|-------|----------|
| 1 | **Bar Chart** | Weekly Revenue by Source | X: `week_end` · Y: `art_revenue`, `pipe_revenue`, `pass_revenue`, `collab_revenue` · Stacking: **stacked** |
| 2 | **Area Chart** | Cumulative Revenue (ETH) | X: `week_end` · Y: `cumulative_revenue` |
| 3 | **Stacked Area** | Revenue Allocation | X: `week_end` · Y: `treasury_allocation`, `active_rewards`, `retroactive_rewards` · Stacking: **stacked** |
| 4 | **Line Chart** | Cumulative BOTTO Burned | X: `week_end` · Y: `cumulative_botto_burnt` |

---

## Query 03 — `03_botto_burns_price.sql`
**Save as:** "Botto - Burns & Price"

| Viz # | Type | Title | Settings |
|-------|------|-------|----------|
| 1 | **Line Chart** | BOTTO Burns & Token Price | X: `week_end` · Left Y: `cumulative_botto_burnt` · Right Y (secondary): `botto_price` · Enable **dual Y-axis** |
| 2 | **Bar Chart** | Weekly BOTTO Burned | X: `week_end` · Y: `weekly_botto_burnt` |

---

## Query 04 — `04_pipes_pass_collabs.sql`
**Save as:** "Botto - Pipes, Pass & Collabs"

| Viz # | Type | Title | Settings |
|-------|------|-------|----------|
| 1 | **Bar Chart** | Pipes, Pass & Collabs Revenue | X: `week_end` · Y: `revenue` · Group by: `source` · Stacking: **grouped** (side by side) |

---

## Query 05 — `05_summary_counters.sql`
**Save as:** "Botto - Revenue KPIs"

Create **one Counter widget per metric** (each is a separate visualization from the same query):

| Viz # | Type | Title | Column | Prefix/Suffix |
|-------|------|-------|--------|---------------|
| 1 | **Counter** | Total Revenue | `grand_total_revenue` | Suffix: `ETH` |
| 2 | **Counter** | Art Revenue | `total_art_revenue` | Suffix: `ETH` |
| 3 | **Counter** | Primary Revenue | `total_primary_revenue` | Suffix: `ETH` |
| 4 | **Counter** | Secondary Revenue | `total_secondary_revenue` | Suffix: `ETH` |
| 5 | **Counter** | 1/1 Artworks Sold | `artworks_sold` | |
| 6 | **Counter** | 1/1 Art Volume | `total_art_volume` | Suffix: `ETH` |

---

## Query 05b — `05b_token_counters.sql`
**Save as:** "Botto - Token KPIs"

| Viz # | Type | Title | Column | Prefix/Suffix |
|-------|------|-------|--------|---------------|
| 1 | **Counter** | BOTTO Burned | `total_botto_burnt` | Suffix: `BOTTO` |
| 2 | **Counter** | BOTTO Price | `current_botto_price` | Prefix: `$` |
| 3 | **Counter** | Rewards Distributed | `total_rewards_distributed` | Suffix: `ETH` |
| 4 | **Counter** | Total Staked | `total_staked` | Suffix: `BOTTO` |

---

## Query 06 — `06_collaborations_table.sql`
**Save as:** "Botto - Collaborations Table"

| Viz # | Type | Title | Settings |
|-------|------|-------|----------|
| 1 | **Table** | Collaborations | Columns: `mint_date`, `collection`, `link`, `revenue_eth` · Sort: `mint_date` asc |

---

## Query 07 — `07_collection_counts.sql`
**Save as:** "Botto - Collection Counts"

| Viz # | Type | Title | Settings |
|-------|------|-------|----------|
| 1 | **Table** | Collection Counts | Columns: `Collection`, `Type`, `Count` · No sort needed (query returns in correct order) |

---

## Query 08 — `08_snapshot_governance.sql`
**Save as:** "Botto - Snapshot Governance"

| Viz # | Type | Title | Settings |
|-------|------|-------|----------|
| 1 | **Table** | Governance Proposals | Columns: `proposal_date`, `title`, `voter_count`, `total_voting_power`, `approval_pct`, `quorum_met`, `result` · Sort: `proposal_date` desc |
| 2 | **Bar Chart** | Monthly Governance Activity | X: `proposal_month` · Y: `monthly_proposal_count` |
| 3 | **Line Chart** | Avg Voters per Month | X: `proposal_month` · Y: `monthly_avg_voters` |

---

## Query 09 — `09_token_supply_breakdown.sql`
**Save as:** "Botto - Token Supply Breakdown"

| Viz # | Type | Title | Settings |
|-------|------|-------|----------|
| 1 | **Area Chart** | BOTTO Token Supply Breakdown | X: `week_end` · Y: `burned`, `gov_staking`, `treasury`, `team`, `airdrop`, `uni_v2_lp`, `uni_v3_lp`, `rewards_wallet`, `liquidity_mining`, `circulating` · Stacking: **stacked** · Order bottom→top: `circulating` first (largest) |

---

## Query 10 — `10_treasury_balance.sql`
**Save as:** "Botto - Treasury Balance"

| Viz # | Type | Title | Settings |
|-------|------|-------|----------|
| 1 | **Counter** | Treasury ETH | Column: `total_eth_value` · Suffix: `ETH` · Row limit: 1, sort `week_end` desc (latest value) |
| 2 | **Counter** | Treasury USD | Column: `total_eth_usd` · Prefix: `$` · Row limit: 1, sort `week_end` desc |
| 3 | **Counter** | Treasury BOTTO | Column: `botto_balance` · Suffix: `BOTTO` · Row limit: 1, sort `week_end` desc |
| 5 | **Stacked Area** | Treasury ETH Composition | X: `week_end` · Y: `eth_balance`, `weth_balance`, `steth_balance`, `wsteth_balance` · Stacking: **stacked** · Labels: "Native ETH" / "WETH" / "stETH" / "wstETH" |
| 6 | **Line Chart** | Treasury BOTTO Balance | X: `week_end` · Y: `botto_balance` |

---

## Query 11 — `11_staking_metrics.sql`
**Save as:** "Botto - Staking Metrics"

| Viz # | Type | Title | Settings |
|-------|------|-------|----------|
| 1 | **Area Chart** | Total BOTTO Staked | X: `week_end` · Y: `total_staked` |
| 2 | **Bar Chart** | Weekly Staking Activity | X: `week_end` · Y: `weekly_staked` (green), `weekly_unstaked` (red) · Stacking: **grouped** |
| 3 | **Line Chart** | Staker Counts | X: `week_end` · Y: `active_stakers`, `new_stakers` |

---

## Query 12 — `12_rewards_distribution.sql`
**Save as:** "Botto - Rewards Distribution"

| Viz # | Type | Title | Settings |
|-------|------|-------|----------|
| 1 | **Bar Chart** | Weekly Rewards (USD) | X: `week_end` · Y: `weekly_eth_rewards_usd`, `weekly_botto_rewards_usd` · Stacking: **stacked** · Labels: "ETH Rewards" / "BOTTO Rewards" |
| 2 | **Area Chart** | Cumulative Rewards (USD) | X: `week_end` · Y: `cumulative_rewards_usd` |
| 3 | **Line Chart** | Weekly Claimers | X: `week_end` · Y: `unique_claimers` |
| 4 | **Bar Chart** | Weekly BOTTO Distributed | X: `week_end` · Y: `weekly_botto_distributed` |
| 5 | **Bar Chart** | Active Rewards: ETH Swapped | X: `week_end` · Y: `weekly_active_eth_swapped` · Label: "ETH swapped to BOTTO for active rewards" |

---

## Query 13 — `13_dex_volume.sql`
**Save as:** "Botto - DEX Volume"

| Viz # | Type | Title | Settings |
|-------|------|-------|----------|
| 1 | **Bar Chart** | Weekly DEX Volume by Chain | X: `week_end` · Y: `eth_volume_usd`, `base_volume_usd` · Stacking: **stacked** · Label Y-series as "Ethereum" / "Base" |
| 2 | **Line Chart** | Cumulative DEX Volume (USD) | X: `week_end` · Y: `cumulative_volume_usd` |
| 3 | **Bar Chart** | Weekly Trade Count | X: `week_end` · Y: `eth_trade_count`, `base_trade_count` · Stacking: **stacked** |

---

## Query 14 — `14_art_sales_performance.sql`
**Save as:** "Botto - Art Sales Performance"

| Viz # | Type | Title | Settings |
|-------|------|-------|----------|
| 1 | **Table** | Period Performance | Columns: `period`, `total_sales`, `primary_count`, `secondary_count`, `total_revenue`, `avg_price`, `min_price`, `max_price`, `primary_pct`, `revenue_change_pct` · Sort: `sort_order` asc · Hide `sort_order` column |
| 2 | **Bar Chart** | Revenue by Period | X: `period` · Y: `total_revenue` · Sort by: `sort_order` asc (chronological order) |

---

## Suggested Dashboard Layout

```
── REVENUE OVERVIEW ──────────────────────────────────────────

Row 1:  [Counter]       [Counter]        [Counter]
        Total Revenue   Artworks 1/1     Rewards Distributed

Row 2:  [============= Weekly Art Revenue by Period (Q01) ==============]

Row 3:  [Weekly Revenue by Source (Q02 viz 1)] [Revenue Allocation (Q02 viz 3)]

Row 4:  [Pipes/Pass/Collabs Revenue (Q04)]     [Burns & Price (Q03 viz 1)]

Row 5:  [Revenue by Period (Q14 viz 2)]        [Period Performance Table (Q14 viz 1)]

── TOKEN & ECONOMICS ─────────────────────────────────────────

Row 6:  [Counter]       [Counter]        [Counter]
        BOTTO Price     BOTTO Burned     Total Staked

Row 7:  [============ BOTTO Token Supply Breakdown (Q09) ===============]

Row 8:  [Total BOTTO Staked (Q11 viz 1)]       [Staking Activity (Q11 viz 2)]

Row 9:  [Staker Counts (Q11 viz 3)]            [Weekly BOTTO Burned (Q03 viz 2)]

Row 10: [DEX Volume by Chain (Q13 viz 1)]      [Cumulative DEX Volume (Q13 viz 2)]

── TREASURY & REWARDS ────────────────────────────────────────

Row 11: [Counter]          [Counter]         [Counter]
        Treasury ETH       Treasury USD      Treasury BOTTO

Row 12: [Treasury ETH Composition (Q10 viz 5)]  [Treasury BOTTO Balance (Q10 viz 6)]

Row 14: [Weekly ETH Distributed (Q12 viz 1)]   [Cumulative ETH Distributed (Q12 viz 2)]

Row 15: [Weekly Claimers (Q12 viz 3)]          [Cumulative USD Distrib (Q12 viz 4)]

── GOVERNANCE ────────────────────────────────────────────────

Row 15: [Governance Proposals Table (Q08 viz 1)                        ]

Row 16: [Monthly Gov Activity (Q08 viz 2)]     [Avg Voters/Month (Q08 viz 3)]

── COLLECTIONS ───────────────────────────────────────────────

Row 17: [Collaborations Table (Q06)            ] [Collection Counts (Q07)]
```
