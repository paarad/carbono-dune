-- ============================================================
-- BOTTO DASHBOARD: Rewards Distribution
-- ============================================================
-- Charts:
--   1. Bar: weekly_eth_distributed
--   2. Area: cumulative_eth_distributed
--   3. Line: unique_claimers
-- X-axis: week_end
-- ============================================================

WITH dates AS (
    SELECT
        TIMESTAMP '2021-10-19 22:00:00' as start_date,
        current_timestamp as end_date
)

, prices AS (
    SELECT
          date_trunc('hour', eth.minute) as week_end
        , date_trunc('hour', eth.minute - INTERVAL '7' DAY) as week_start
        , eth.price as eth_price
    FROM prices.usd eth
    JOIN prices.usd botto
        ON botto.minute = eth.minute
    WHERE   botto.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
        AND eth.contract_address = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
        AND botto.minute >= (SELECT start_date + INTERVAL '7' DAY FROM dates)
        AND botto.minute <= (SELECT end_date FROM dates)
        AND day_of_week(botto.minute) = 2
        AND hour(botto.minute) = 22
        AND minute(botto.minute) = 0
)

-- ETH outflows from rewards wallet
, reward_events AS (
    SELECT
          tr.block_time as event_time
        , tr."to" as claimer
        , tr.value / 1e18 as eth_amount
    FROM ethereum.traces tr
    WHERE tr."from" = 0x93298241417a63469b6f8f080b4878749acb4c47
      AND tr.block_time >= (SELECT start_date FROM dates)
      AND tr.block_time < (SELECT end_date FROM dates)
      AND tr.success = true
      AND tr.type NOT IN ('delegatecall', 'staticcall')
      AND tr.value > 0
)

, weekly_rewards AS (
    SELECT
          p.week_end
        , ROUND(SUM(r.eth_amount), 4) as eth_distributed
        , COUNT(DISTINCT r.claimer) as unique_claimers
    FROM reward_events r
    JOIN prices p ON r.event_time >= p.week_start AND r.event_time < p.week_end
    GROUP BY p.week_end
)

SELECT
      p.week_end
    , COALESCE(wr.eth_distributed, 0) as weekly_eth_distributed
    , ROUND(COALESCE(wr.eth_distributed, 0) * p.eth_price, 2) as weekly_usd_distributed
    , COALESCE(wr.unique_claimers, 0) as unique_claimers
    , ROUND(SUM(COALESCE(wr.eth_distributed, 0)) OVER (ORDER BY p.week_end ASC), 4) as cumulative_eth_distributed
    , ROUND(SUM(COALESCE(wr.eth_distributed, 0) * p.eth_price) OVER (ORDER BY p.week_end ASC), 2) as cumulative_usd_distributed
FROM prices p
LEFT JOIN weekly_rewards wr ON wr.week_end = p.week_end
ORDER BY p.week_end ASC
