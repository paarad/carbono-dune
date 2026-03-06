-- ============================================================
-- BOTTO DASHBOARD: Treasury Balance
-- ============================================================
-- Treasury addresses (combined):
--   0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49 (current)
--   0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c (botto.eth initial)
--   0xfd25808ffffbef621c4dbf0171fa647c916cb33b (DAO payroll)
-- Tracks: Native ETH + WETH + stETH + wstETH + BOTTO
-- Approach: same start_date as query 09 to capture all activity
--   Native ETH: ethereum.traces (inline week bucketing, no range JOIN)
--   ERC20: erc20_ethereum.evt_Transfer (WETH + stETH + wstETH + BOTTO)
-- Charts:
--   1. Stacked area: eth_balance, weth_balance, steth_balance, wsteth_balance
--   2. Line: total_eth_usd
--   3. Area: botto_balance
-- X-axis: week_end
-- ============================================================

WITH dates AS (
    SELECT
        TIMESTAMP '2021-10-05 22:00:00' as start_date,
        current_timestamp as end_date
)

-- ETH-only prices (no BOTTO join needed — treasury existed before BOTTO had price data)
, prices AS (
    SELECT
          date_trunc('hour', eth.minute) as week_end
        , MAX(eth.price) as eth_price
    FROM prices.usd eth
    WHERE eth.contract_address = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
        AND eth.minute >= (SELECT start_date + INTERVAL '7' DAY FROM dates)
        AND eth.minute <= (SELECT end_date FROM dates)
        AND day_of_week(eth.minute) = 2
        AND hour(eth.minute) = 22
        AND minute(eth.minute) = 0
    GROUP BY 1
)

-- ─── Native ETH flows (ethereum.traces) ───────────────────────
-- Inline week bucketing avoids expensive range JOIN with prices
-- Excludes WETH wrap/unwrap and stETH staking (tracked in erc20_flows)
, eth_flows AS (
    SELECT
          date_trunc('week', t.block_time - INTERVAL '1' DAY - INTERVAL '22' HOUR)
              + INTERVAL '8' DAY + INTERVAL '22' HOUR as week_end
        , SUM(CASE WHEN t."to" IN (
              0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49,
              0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
              0xfd25808ffffbef621c4dbf0171fa647c916cb33b)
            THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" IN (
              0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49,
              0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
              0xfd25808ffffbef621c4dbf0171fa647c916cb33b)
            THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as eth_net
    FROM ethereum.traces t
    WHERE t.block_time >= (SELECT start_date FROM dates)
      AND t.block_time < (SELECT end_date FROM dates)
      AND t.success = true
      AND (t.call_type NOT IN ('delegatecall', 'staticcall') OR t.call_type IS NULL)
      AND t.value > UINT256 '0'
      AND (
          t."to" IN (
              0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49,
              0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
              0xfd25808ffffbef621c4dbf0171fa647c916cb33b)
          OR t."from" IN (
              0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49,
              0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
              0xfd25808ffffbef621c4dbf0171fa647c916cb33b)
      )
      -- Don't double-count: wrapping ETH→WETH or staking ETH→stETH
      -- (those are tracked as ERC20 inflows in erc20_flows)
      AND t."to" NOT IN (
          0xc02aaa39b223fe8d0a0e5c4b8d68103a3ea9782b,
          0xae7ab96520de3a18e5e111b5eaab095312d7fe84
      )
      AND t."from" NOT IN (
          0xc02aaa39b223fe8d0a0e5c4b8d68103a3ea9782b,
          0xae7ab96520de3a18e5e111b5eaab095312d7fe84
      )
    GROUP BY 1
)

-- ─── ERC20 flows (WETH + stETH + wstETH + BOTTO) ─────────────
, erc20_flows AS (
    SELECT
          date_trunc('week', t.evt_block_time - INTERVAL '1' DAY - INTERVAL '22' HOUR)
              + INTERVAL '8' DAY + INTERVAL '22' HOUR as week_end
        -- WETH
        , SUM(CASE WHEN t.contract_address = 0xc02aaa39b223fe8d0a0e5c4b8d68103a3ea9782b
                    AND t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0xfd25808ffffbef621c4dbf0171fa647c916cb33b)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t.contract_address = 0xc02aaa39b223fe8d0a0e5c4b8d68103a3ea9782b
                    AND t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0xfd25808ffffbef621c4dbf0171fa647c916cb33b)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as weth_net
        -- stETH
        , SUM(CASE WHEN t.contract_address = 0xae7ab96520de3a18e5e111b5eaab095312d7fe84
                    AND t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0xfd25808ffffbef621c4dbf0171fa647c916cb33b)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t.contract_address = 0xae7ab96520de3a18e5e111b5eaab095312d7fe84
                    AND t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0xfd25808ffffbef621c4dbf0171fa647c916cb33b)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as steth_net
        -- wstETH
        , SUM(CASE WHEN t.contract_address = 0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0
                    AND t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0xfd25808ffffbef621c4dbf0171fa647c916cb33b)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t.contract_address = 0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0
                    AND t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0xfd25808ffffbef621c4dbf0171fa647c916cb33b)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as wsteth_net
        -- BOTTO
        , SUM(CASE WHEN t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
                    AND t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0xfd25808ffffbef621c4dbf0171fa647c916cb33b)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
                    AND t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0xfd25808ffffbef621c4dbf0171fa647c916cb33b)
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as botto_net
    FROM erc20_ethereum.evt_Transfer t
    WHERE t.contract_address IN (
              0xc02aaa39b223fe8d0a0e5c4b8d68103a3ea9782b,
              0xae7ab96520de3a18e5e111b5eaab095312d7fe84,
              0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0,
              0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
          )
      AND t.evt_block_time >= (SELECT start_date FROM dates)
      AND t.evt_block_time < (SELECT end_date FROM dates)
      AND (t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0xfd25808ffffbef621c4dbf0171fa647c916cb33b)
           OR t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0xfd25808ffffbef621c4dbf0171fa647c916cb33b))
    GROUP BY 1
)

-- ─── OUTPUT ───────────────────────────────────────────────────
SELECT
      p.week_end
    , p.eth_price
    -- Individual balances (cumulative)
    , ROUND(COALESCE(SUM(ef.eth_net) OVER (ORDER BY p.week_end ASC), 0), 4) as eth_balance
    , ROUND(COALESCE(SUM(e.weth_net) OVER (ORDER BY p.week_end ASC), 0), 4) as weth_balance
    , ROUND(COALESCE(SUM(e.steth_net) OVER (ORDER BY p.week_end ASC), 0), 4) as steth_balance
    , ROUND(COALESCE(SUM(e.wsteth_net) OVER (ORDER BY p.week_end ASC), 0), 4) as wsteth_balance
    -- Total ETH-equivalent (native + WETH + stETH + wstETH, all ~1:1)
    , ROUND(
          COALESCE(SUM(ef.eth_net) OVER (ORDER BY p.week_end ASC), 0)
        + COALESCE(SUM(e.weth_net) OVER (ORDER BY p.week_end ASC), 0)
        + COALESCE(SUM(e.steth_net) OVER (ORDER BY p.week_end ASC), 0)
        + COALESCE(SUM(e.wsteth_net) OVER (ORDER BY p.week_end ASC), 0)
      , 4) as total_eth_value
    -- USD value
    , ROUND((
          COALESCE(SUM(ef.eth_net) OVER (ORDER BY p.week_end ASC), 0)
        + COALESCE(SUM(e.weth_net) OVER (ORDER BY p.week_end ASC), 0)
        + COALESCE(SUM(e.steth_net) OVER (ORDER BY p.week_end ASC), 0)
        + COALESCE(SUM(e.wsteth_net) OVER (ORDER BY p.week_end ASC), 0)
      ) * p.eth_price, 2) as total_eth_usd
    -- BOTTO balance
    , ROUND(COALESCE(SUM(e.botto_net) OVER (ORDER BY p.week_end ASC), 0), 4) as botto_balance
FROM prices p
LEFT JOIN eth_flows ef ON ef.week_end = p.week_end
LEFT JOIN erc20_flows e ON e.week_end = p.week_end
ORDER BY p.week_end ASC

