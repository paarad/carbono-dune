-- ============================================================
-- BOTTO DASHBOARD: Staking Metrics
-- ============================================================
-- Charts:
--   1. Area: total_staked (cumulative)
--   2. Bar: weekly_staked, weekly_unstaked
--   3. Line: unique_stakers, new_stakers
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

-- Staking transfers (BOTTO sent to gov_staking contract)
, stake_events AS (
    SELECT
          t.evt_block_time as event_time
        , t."from" as staker
        , CAST(t.value AS DOUBLE) / 1e18 as amount
    FROM erc20_ethereum.evt_Transfer t
    WHERE t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND t."to" = 0x19cd3998f106ecc40ee7668c19c47e18b491e8a6
      AND t.evt_block_time >= (SELECT start_date FROM dates)
      AND t.evt_block_time < (SELECT end_date FROM dates)
)

-- Unstaking transfers (BOTTO sent from gov_staking contract)
, unstake_events AS (
    SELECT
          t.evt_block_time as event_time
        , t."to" as staker
        , CAST(t.value AS DOUBLE) / 1e18 as amount
    FROM erc20_ethereum.evt_Transfer t
    WHERE t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND t."from" = 0x19cd3998f106ecc40ee7668c19c47e18b491e8a6
      AND t.evt_block_time >= (SELECT start_date FROM dates)
      AND t.evt_block_time < (SELECT end_date FROM dates)
)

-- First stake per address for "new stakers" metric
, first_stakes AS (
    SELECT staker, MIN(event_time) as first_stake_time
    FROM stake_events
    GROUP BY staker
)

-- Weekly staking volumes
, weekly_stakes AS (
    SELECT p.week_end,
        ROUND(SUM(s.amount), 4) as staked_amount,
        COUNT(DISTINCT s.staker) as staker_count
    FROM stake_events s
    JOIN prices p ON s.event_time >= p.week_start AND s.event_time < p.week_end
    GROUP BY p.week_end
)

, weekly_unstakes AS (
    SELECT p.week_end,
        ROUND(SUM(u.amount), 4) as unstaked_amount,
        COUNT(DISTINCT u.staker) as unstaker_count
    FROM unstake_events u
    JOIN prices p ON u.event_time >= p.week_start AND u.event_time < p.week_end
    GROUP BY p.week_end
)

-- New stakers per week
, weekly_new_stakers AS (
    SELECT p.week_end, COUNT(DISTINCT fs.staker) as new_stakers
    FROM first_stakes fs
    JOIN prices p ON fs.first_stake_time >= p.week_start AND fs.first_stake_time < p.week_end
    GROUP BY p.week_end
)

SELECT
      p.week_end
    , COALESCE(ws.staked_amount, 0) as weekly_staked
    , COALESCE(wu.unstaked_amount, 0) as weekly_unstaked
    , ROUND(SUM(COALESCE(ws.staked_amount, 0) - COALESCE(wu.unstaked_amount, 0))
            OVER (ORDER BY p.week_end ASC), 4) as total_staked
    , COALESCE(ws.staker_count, 0) + COALESCE(wu.unstaker_count, 0) as unique_stakers
    , COALESCE(wns.new_stakers, 0) as new_stakers
FROM prices p
LEFT JOIN weekly_stakes ws ON ws.week_end = p.week_end
LEFT JOIN weekly_unstakes wu ON wu.week_end = p.week_end
LEFT JOIN weekly_new_stakers wns ON wns.week_end = p.week_end
ORDER BY p.week_end ASC
