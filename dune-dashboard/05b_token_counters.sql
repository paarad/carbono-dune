-- ============================================================
-- BOTTO DASHBOARD: Token & Protocol Counters
-- ============================================================
-- Chart: Counter widgets (one per metric)
-- Split from 05_summary_counters.sql for performance
-- Covers: BOTTO burns, price, rewards distributed, total staked
-- ============================================================

WITH dates AS (
    SELECT
        TIMESTAMP '2021-10-19 22:00:00' as start_date,
        current_timestamp as end_date
)

, current_price AS (
    SELECT price as botto_price
    FROM prices.usd
    WHERE symbol = 'BOTTO'
      AND minute > current_timestamp - INTERVAL '1' DAY
    ORDER BY minute DESC
    LIMIT 1
)

, burn_totals AS (
    SELECT ROUND(SUM(bb.value * power(10, -18)), 4) as total_botto_burnt
    FROM erc20_ethereum.evt_Transfer bb
    WHERE bb.evt_block_time >= (SELECT start_date FROM dates) AND bb.evt_block_time < (SELECT end_date FROM dates)
      AND bb.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND bb."to" = 0x000000000000000000000000000000000000dead
)

, rewards_totals AS (
    SELECT ROUND(SUM(tr.value / 1e18), 4) as total_eth_distributed
    FROM ethereum.traces tr
    WHERE tr."from" = 0x93298241417a63469b6f8f080b4878749acb4c47
      AND tr.block_time >= (SELECT start_date FROM dates)
      AND tr.block_time < (SELECT end_date FROM dates)
      AND tr.success = true
      AND tr.type NOT IN ('delegatecall', 'staticcall')
      AND tr.value > 0
)

, staking_totals AS (
    SELECT ROUND(
        SUM(CASE WHEN t."to" = 0x19cd3998f106ecc40ee7668c19c47e18b491e8a6 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
      - SUM(CASE WHEN t."from" = 0x19cd3998f106ecc40ee7668c19c47e18b491e8a6 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
    , 4) as total_staked
    FROM erc20_ethereum.evt_Transfer t
    WHERE t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND (t."to" = 0x19cd3998f106ecc40ee7668c19c47e18b491e8a6
           OR t."from" = 0x19cd3998f106ecc40ee7668c19c47e18b491e8a6)
)

SELECT
      burn.total_botto_burnt
    , cp.botto_price as current_botto_price
    , COALESCE(rw.total_eth_distributed, 0) as total_rewards_distributed
    , COALESCE(st.total_staked, 0) as total_staked
FROM burn_totals burn
CROSS JOIN current_price cp
CROSS JOIN rewards_totals rw
CROSS JOIN staking_totals st
