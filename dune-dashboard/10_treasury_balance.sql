-- ============================================================
-- BOTTO DASHBOARD: Treasury Balance (ETH + stETH + BOTTO)
-- ============================================================
-- Treasury addresses (combined):
--   0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49 (current)
--   0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c (botto.eth initial)
-- Charts:
--   1. Area: eth_balance + steth_balance stacked (total ETH-equivalent)
--   2. Bar: eth_inflow, eth_outflow per week
--   3. Line: total_eth_usd
--   4. Line: botto_balance
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

-- ─── NATIVE ETH ────────────────────────────────────────────

-- Initial native ETH balance before tracking window
, initial_eth AS (
    SELECT
          SUM(CASE WHEN tr."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                   THEN CAST(tr.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN tr."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                   THEN CAST(tr.value AS DOUBLE) / 1e18 ELSE 0 END)
          as balance
    FROM ethereum.traces tr
    WHERE tr.block_time < (SELECT start_date FROM dates)
      AND tr.success = true
      AND tr.tx_success = true
      AND tr.type NOT IN ('delegatecall', 'staticcall', 'callcode')
      AND tr.value > UINT256 '0'
      AND (tr."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
           OR tr."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c))
)

-- Weekly native ETH flows
, eth_flows AS (
    SELECT
          p.week_end
        , SUM(CASE WHEN tr."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                   THEN CAST(tr.value AS DOUBLE) / 1e18 ELSE 0 END) as eth_inflow
        , SUM(CASE WHEN tr."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                   THEN CAST(tr.value AS DOUBLE) / 1e18 ELSE 0 END) as eth_outflow
    FROM ethereum.traces tr
    JOIN prices p ON tr.block_time >= p.week_start AND tr.block_time < p.week_end
    WHERE tr.block_time >= (SELECT start_date FROM dates)
      AND tr.block_time < (SELECT end_date FROM dates)
      AND tr.success = true
      AND tr.tx_success = true
      AND tr.type NOT IN ('delegatecall', 'staticcall', 'callcode')
      AND tr.value > UINT256 '0'
      AND (tr."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
           OR tr."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c))
      -- Exclude internal transfers between the two treasury wallets
      AND NOT (tr."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
           AND tr."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c))
    GROUP BY p.week_end
)

-- ─── stETH + wstETH (Lido staking position) ────────────────
-- stETH:  0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
-- wstETH: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
-- Note: stETH rebases daily — transfer tracking captures deposits/withdrawals
--       but not accrued staking rewards. Balance is approximate.

, initial_steth AS (
    SELECT
          SUM(CASE WHEN t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as balance
    FROM erc20_ethereum.evt_Transfer t
    WHERE t.contract_address IN (
              0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84,
              0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
          )
      AND t.evt_block_time < (SELECT start_date FROM dates)
      AND (t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
           OR t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c))
)

, steth_flows AS (
    SELECT
          p.week_end
        , SUM(CASE WHEN t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as steth_net
    FROM erc20_ethereum.evt_Transfer t
    JOIN prices p ON t.evt_block_time >= p.week_start AND t.evt_block_time < p.week_end
    WHERE t.contract_address IN (
              0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84,
              0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
          )
      AND t.evt_block_time >= (SELECT start_date FROM dates)
      AND t.evt_block_time < (SELECT end_date FROM dates)
      AND (t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
           OR t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c))
    GROUP BY p.week_end
)

-- ─── BOTTO ──────────────────────────────────────────────────

, initial_botto AS (
    SELECT
          SUM(CASE WHEN t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as balance
    FROM erc20_ethereum.evt_Transfer t
    WHERE t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND t.evt_block_time < (SELECT start_date FROM dates)
      AND (t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
           OR t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c))
)

, botto_flows AS (
    SELECT
          p.week_end
        , SUM(CASE WHEN t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as botto_net
    FROM erc20_ethereum.evt_Transfer t
    JOIN prices p ON t.evt_block_time >= p.week_start AND t.evt_block_time < p.week_end
    WHERE t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND t.evt_block_time >= (SELECT start_date FROM dates)
      AND t.evt_block_time < (SELECT end_date FROM dates)
      AND (t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
           OR t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c))
    GROUP BY p.week_end
)

-- ─── OUTPUT ─────────────────────────────────────────────────

SELECT
      p.week_end
    , ROUND(COALESCE(ef.eth_inflow, 0), 4) as eth_inflow
    , ROUND(COALESCE(ef.eth_outflow, 0), 4) as eth_outflow
    , ROUND(COALESCE(ef.eth_inflow, 0) - COALESCE(ef.eth_outflow, 0), 4) as eth_net
    -- Native ETH balance
    , ROUND(COALESCE((SELECT balance FROM initial_eth), 0)
        + SUM(COALESCE(ef.eth_inflow, 0) - COALESCE(ef.eth_outflow, 0))
              OVER (ORDER BY p.week_end ASC), 4) as eth_balance
    -- stETH + wstETH balance (Lido staking position, ~1:1 with ETH)
    , ROUND(COALESCE((SELECT balance FROM initial_steth), 0)
        + COALESCE(SUM(sf.steth_net) OVER (ORDER BY p.week_end ASC), 0), 4) as steth_balance
    -- Total ETH-equivalent value (native + staked)
    , ROUND(
        COALESCE((SELECT balance FROM initial_eth), 0)
        + SUM(COALESCE(ef.eth_inflow, 0) - COALESCE(ef.eth_outflow, 0))
              OVER (ORDER BY p.week_end ASC)
        + COALESCE((SELECT balance FROM initial_steth), 0)
        + COALESCE(SUM(sf.steth_net) OVER (ORDER BY p.week_end ASC), 0)
      , 4) as total_eth_value
    -- USD value of total ETH holdings
    , ROUND((
        COALESCE((SELECT balance FROM initial_eth), 0)
        + SUM(COALESCE(ef.eth_inflow, 0) - COALESCE(ef.eth_outflow, 0))
              OVER (ORDER BY p.week_end ASC)
        + COALESCE((SELECT balance FROM initial_steth), 0)
        + COALESCE(SUM(sf.steth_net) OVER (ORDER BY p.week_end ASC), 0)
      ) * p.eth_price, 2) as total_eth_usd
    -- BOTTO balance
    , ROUND(COALESCE((SELECT balance FROM initial_botto), 0)
        + COALESCE(SUM(bf.botto_net) OVER (ORDER BY p.week_end ASC), 0), 4) as botto_balance
FROM prices p
LEFT JOIN eth_flows ef ON ef.week_end = p.week_end
LEFT JOIN steth_flows sf ON sf.week_end = p.week_end
LEFT JOIN botto_flows bf ON bf.week_end = p.week_end
ORDER BY p.week_end ASC
