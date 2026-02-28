-- ============================================================
-- BOTTO DASHBOARD: Rewards Distribution
-- ============================================================
-- Two reward mechanisms:
--   1. ETH rewards: ETH outflows from 0x93298... (old rewards wallet)
--   2. BOTTO rewards: BOTTO distributed from 0x9b627... (instant rewards wallet)
--      - Instant rewards: BOTTO sent to voters
--      - Active rewards: ETH swapped to BOTTO on art sale, then distributed
--      - Works on both Ethereum and Base
-- Charts:
--   1. Stacked Bar: weekly_eth_rewards_usd + weekly_botto_rewards_usd
--   2. Area: cumulative_rewards_usd
--   3. Line: unique_claimers
--   4. Bar: weekly_botto_distributed (in BOTTO)
--   5. Bar: weekly_active_eth_swapped (ETH fed into DEX swaps for active rewards)
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
        , MAX(eth.price) as eth_price
        , MIN(botto.price) as botto_price
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
    GROUP BY 1, 2
)

-- ─── ETH REWARDS (old mechanism) ────────────────────────────
-- Wallet: 0x93298241417a63469b6f8f080b4878749acb4c47

, eth_reward_events AS (
    SELECT
          tr.block_time as event_time
        , tr."to" as claimer
        , CAST(tr.value AS DOUBLE) / 1e18 as eth_amount
    FROM ethereum.traces tr
    WHERE tr."from" = 0x93298241417a63469b6f8f080b4878749acb4c47
      AND tr.block_time >= (SELECT start_date FROM dates)
      AND tr.block_time < (SELECT end_date FROM dates)
      AND tr.success = true
      AND tr.tx_success = true
      AND tr.type NOT IN ('delegatecall', 'staticcall', 'callcode')
      AND tr.value > UINT256 '0'
)

-- ─── ACTIVE REWARDS: ETH swapped to BOTTO (both chains) ─────
-- Wallet: 0x9b627aF2a48F2E07BEeeb82141e3AC6E231326bF
-- When art sells, this wallet receives ETH, swaps it to BOTTO via DEX,
-- then distributes BOTTO to participants. We track the ETH going into swaps.

, active_eth_swap_events AS (
    -- Ethereum: ETH sent by rewards wallet (swap to BOTTO)
    SELECT
          tr.block_time as event_time
        , CAST(tr.value AS DOUBLE) / 1e18 as eth_amount
    FROM ethereum.traces tr
    WHERE tr."from" = 0x9b627af2a48f2e07beeeb82141e3ac6e231326bf
      AND tr.block_time >= (SELECT start_date FROM dates)
      AND tr.block_time < (SELECT end_date FROM dates)
      AND tr.success = true
      AND tr.tx_success = true
      AND tr.type NOT IN ('delegatecall', 'staticcall', 'callcode')
      AND tr.value > UINT256 '0'

    UNION ALL

    -- Base: ETH sent by rewards wallet (swap to BOTTO)
    SELECT
          tr.block_time as event_time
        , CAST(tr.value AS DOUBLE) / 1e18 as eth_amount
    FROM base.traces tr
    WHERE tr."from" = 0x9b627af2a48f2e07beeeb82141e3ac6e231326bf
      AND tr.block_time >= (SELECT start_date FROM dates)
      AND tr.block_time < (SELECT end_date FROM dates)
      AND tr.success = true
      AND tr.tx_success = true
      AND tr.type NOT IN ('delegatecall', 'staticcall', 'callcode')
      AND tr.value > UINT256 '0'
)

-- ─── BOTTO REWARDS (instant + active, both chains) ──────────
-- Wallet: 0x9b627aF2a48F2E07BEeeb82141e3AC6E231326bF
-- Ethereum BOTTO: 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
-- Base BOTTO:     0x24914cb6bd01e6a0cf2a9c0478e33c25926e6a0c

, botto_reward_events AS (
    -- Ethereum BOTTO rewards
    SELECT
          t.evt_block_time as event_time
        , t."to" as claimer
        , CAST(t.value AS DOUBLE) / 1e18 as botto_amount
    FROM erc20_ethereum.evt_Transfer t
    WHERE t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND t."from" = 0x9b627af2a48f2e07beeeb82141e3ac6e231326bf
      AND t.evt_block_time >= (SELECT start_date FROM dates)
      AND t.evt_block_time < (SELECT end_date FROM dates)

    UNION ALL

    -- Base BOTTO rewards
    SELECT
          t.evt_block_time as event_time
        , t."to" as claimer
        , CAST(t.value AS DOUBLE) / 1e18 as botto_amount
    FROM erc20_base.evt_Transfer t
    WHERE t.contract_address = 0x24914cb6bd01e6a0cf2a9c0478e33c25926e6a0c
      AND t."from" = 0x9b627af2a48f2e07beeeb82141e3ac6e231326bf
      AND t.evt_block_time >= (SELECT start_date FROM dates)
      AND t.evt_block_time < (SELECT end_date FROM dates)
)

-- Weekly ETH rewards
, weekly_eth_rewards AS (
    SELECT
          p.week_end
        , ROUND(SUM(r.eth_amount), 4) as eth_distributed
    FROM eth_reward_events r
    JOIN prices p ON r.event_time >= p.week_start AND r.event_time < p.week_end
    GROUP BY p.week_end
)

-- Weekly active rewards: ETH swapped to BOTTO (both chains)
, weekly_active_eth AS (
    SELECT
          p.week_end
        , ROUND(SUM(r.eth_amount), 4) as active_eth_swapped
    FROM active_eth_swap_events r
    JOIN prices p ON r.event_time >= p.week_start AND r.event_time < p.week_end
    GROUP BY p.week_end
)

-- Weekly BOTTO rewards (both chains combined)
, weekly_botto_rewards AS (
    SELECT
          p.week_end
        , ROUND(SUM(r.botto_amount), 4) as botto_distributed
    FROM botto_reward_events r
    JOIN prices p ON r.event_time >= p.week_start AND r.event_time < p.week_end
    GROUP BY p.week_end
)

-- Unique claimers per week (all reward types combined)
, weekly_claimers AS (
    SELECT p.week_end, COUNT(DISTINCT all_rewards.claimer) as unique_claimers
    FROM (
        SELECT event_time, claimer FROM eth_reward_events
        UNION ALL
        SELECT event_time, claimer FROM botto_reward_events
    ) all_rewards
    JOIN prices p ON all_rewards.event_time >= p.week_start AND all_rewards.event_time < p.week_end
    GROUP BY p.week_end
)

-- Materialize all weekly values first (no NULLs, no JOINs in the window layer)
, weekly_combined AS (
    SELECT
          p.week_end
        , p.eth_price
        , COALESCE(p.botto_price, 0) as botto_price
        , COALESCE(wer.eth_distributed, 0) as eth_distributed
        , COALESCE(wae.active_eth_swapped, 0) as active_eth_swapped
        , COALESCE(wbr.botto_distributed, 0) as botto_distributed
        , COALESCE(wc.unique_claimers, 0) as unique_claimers
    FROM prices p
    LEFT JOIN weekly_eth_rewards wer ON wer.week_end = p.week_end
    LEFT JOIN weekly_active_eth wae ON wae.week_end = p.week_end
    LEFT JOIN weekly_botto_rewards wbr ON wbr.week_end = p.week_end
    LEFT JOIN weekly_claimers wc ON wc.week_end = p.week_end
)

SELECT
      week_end
    , eth_price
    -- Weekly values
    , eth_distributed as weekly_eth_distributed
    , botto_distributed as weekly_botto_distributed
    , active_eth_swapped as weekly_active_eth_swapped
    , ROUND(active_eth_swapped * eth_price, 2) as weekly_active_eth_usd
    , ROUND(eth_distributed * eth_price, 2) as weekly_eth_rewards_usd
    , ROUND(botto_distributed * botto_price, 2) as weekly_botto_rewards_usd
    , ROUND((eth_distributed + active_eth_swapped) * eth_price
          + botto_distributed * botto_price, 2) as weekly_rewards_usd
    , unique_claimers
    -- Cumulative ETH: old direct + active swapped
    , ROUND(SUM(eth_distributed + active_eth_swapped)
            OVER (ORDER BY week_end ASC), 4) as cumulative_eth_distributed
    -- Cumulative active ETH swapped (separate for viz)
    , ROUND(SUM(active_eth_swapped)
            OVER (ORDER BY week_end ASC), 4) as cumulative_active_eth_swapped
    -- Cumulative BOTTO
    , ROUND(SUM(botto_distributed)
            OVER (ORDER BY week_end ASC), 4) as cumulative_botto_distributed
    -- Cumulative USD (locked at each week's price, only goes up)
    , ROUND(SUM((eth_distributed + active_eth_swapped) * eth_price)
            OVER (ORDER BY week_end ASC), 2) as cumulative_eth_rewards_usd
    , ROUND(SUM(botto_distributed * botto_price)
            OVER (ORDER BY week_end ASC), 2) as cumulative_botto_rewards_usd
    , ROUND(SUM((eth_distributed + active_eth_swapped) * eth_price + botto_distributed * botto_price)
            OVER (ORDER BY week_end ASC), 2) as cumulative_rewards_usd
FROM weekly_combined
ORDER BY week_end ASC
