-- ============================================================
-- BOTTO DASHBOARD: Staking Metrics
-- ============================================================
-- Charts:
--   1. Area: total_staked (cumulative BOTTO in staking contract)
--   2. Bar: weekly_staked, weekly_unstaked
--   3. Line: active_stakers (wallets with positive balance), new_stakers
-- X-axis: week_end
-- ============================================================

WITH dates AS (
    SELECT
        TIMESTAMP '2021-10-19 22:00:00' as start_date,
        current_timestamp as end_date
)

, prices AS (
    SELECT DISTINCT
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

-- All staking events (all time — needed for accurate staker counts)
, staker_events AS (
    -- Stakes (positive)
    SELECT t."from" as staker, t.evt_block_time as event_time,
           CAST(t.value AS DOUBLE) / 1e18 as amount
    FROM erc20_ethereum.evt_Transfer t
    WHERE t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND t."to" = 0x19cd3998f106ecc40ee7668c19c47e18b491e8a6

    UNION ALL

    -- Unstakes (negative)
    SELECT t."to" as staker, t.evt_block_time,
           -CAST(t.value AS DOUBLE) / 1e18
    FROM erc20_ethereum.evt_Transfer t
    WHERE t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND t."from" = 0x19cd3998f106ecc40ee7668c19c47e18b491e8a6
)

-- First stake per wallet (all time, for "new stakers")
, first_stakes AS (
    SELECT staker, MIN(event_time) as first_stake_time
    FROM staker_events
    WHERE amount > 0
    GROUP BY staker
)

-- Per-wallet balances from before our tracking window
, initial_staker_balances AS (
    SELECT staker, SUM(amount) as balance
    FROM staker_events
    WHERE event_time < (SELECT start_date FROM dates)
    GROUP BY staker
    HAVING SUM(amount) <> 0
)

-- Per staker per week: net change (in-window events only)
, staker_weekly_changes AS (
    SELECT se.staker, p.week_end, SUM(se.amount) as net_change
    FROM staker_events se
    JOIN prices p ON se.event_time >= p.week_start AND se.event_time < p.week_end
    GROUP BY se.staker, p.week_end
)

-- Merge initial balances (→ first week) with weekly changes
, staker_weekly AS (
    SELECT staker, week_end, SUM(net_change) as net_change
    FROM (
        SELECT staker, (SELECT MIN(week_end) FROM prices) as week_end, balance as net_change
        FROM initial_staker_balances

        UNION ALL

        SELECT staker, week_end, net_change
        FROM staker_weekly_changes
    ) t
    GROUP BY staker, week_end
)

-- Per staker: running balance after each active week
, staker_running AS (
    SELECT staker, week_end, net_change,
           SUM(net_change) OVER (PARTITION BY staker ORDER BY week_end ASC) as running_balance
    FROM staker_weekly
)

-- Detect entries (balance 0→positive) and exits (balance positive→0) per week
, staker_transitions AS (
    SELECT week_end,
           SUM(CASE WHEN running_balance > 0
                     AND (running_balance - net_change) <= 0 THEN 1 ELSE 0 END) as entries,
           SUM(CASE WHEN running_balance <= 0
                     AND (running_balance - net_change) > 0 THEN 1 ELSE 0 END) as exits
    FROM staker_running
    GROUP BY week_end
)

-- Weekly staking volumes
, weekly_volumes AS (
    SELECT p.week_end,
           ROUND(SUM(CASE WHEN se.amount > 0 THEN se.amount ELSE 0 END), 4) as weekly_staked,
           ROUND(SUM(CASE WHEN se.amount < 0 THEN -se.amount ELSE 0 END), 4) as weekly_unstaked
    FROM staker_events se
    JOIN prices p ON se.event_time >= p.week_start AND se.event_time < p.week_end
    WHERE se.event_time >= (SELECT start_date FROM dates)
    GROUP BY p.week_end
)

-- New stakers per week (first-time stakers only)
, weekly_new_stakers AS (
    SELECT p.week_end, COUNT(DISTINCT fs.staker) as new_stakers
    FROM first_stakes fs
    JOIN prices p ON fs.first_stake_time >= p.week_start AND fs.first_stake_time < p.week_end
    GROUP BY p.week_end
)

-- Total staked before tracking window (for cumulative chart)
, initial_total AS (
    SELECT COALESCE(SUM(balance), 0) as initial_staked
    FROM initial_staker_balances
    WHERE balance > 0
)

SELECT
      p.week_end
    , COALESCE(wv.weekly_staked, 0) as weekly_staked
    , COALESCE(wv.weekly_unstaked, 0) as weekly_unstaked
    , ROUND((SELECT initial_staked FROM initial_total)
        + SUM(COALESCE(wv.weekly_staked, 0) - COALESCE(wv.weekly_unstaked, 0))
              OVER (ORDER BY p.week_end ASC), 4) as total_staked
    , SUM(COALESCE(st.entries, 0) - COALESCE(st.exits, 0))
          OVER (ORDER BY p.week_end ASC) as active_stakers
    , COALESCE(wns.new_stakers, 0) as new_stakers
FROM prices p
LEFT JOIN weekly_volumes wv ON wv.week_end = p.week_end
LEFT JOIN staker_transitions st ON st.week_end = p.week_end
LEFT JOIN weekly_new_stakers wns ON wns.week_end = p.week_end
ORDER BY p.week_end ASC
