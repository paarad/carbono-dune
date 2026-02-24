-- ============================================================
-- BOTTO DASHBOARD: Treasury Balance (ETH + BOTTO)
-- ============================================================
-- Charts:
--   1. Area: eth_balance (cumulative)
--   2. Bar: eth_inflow, eth_outflow per week
--   3. Line: eth_balance_usd
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

-- ETH flows via traces
, eth_flows AS (
    SELECT
          p.week_end
        , SUM(CASE WHEN tr."to" = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
                   THEN tr.value / 1e18 ELSE 0 END) as eth_inflow
        , SUM(CASE WHEN tr."from" = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
                   THEN tr.value / 1e18 ELSE 0 END) as eth_outflow
    FROM ethereum.traces tr
    JOIN prices p ON tr.block_time >= p.week_start AND tr.block_time < p.week_end
    WHERE tr.block_time >= (SELECT start_date FROM dates)
      AND tr.block_time < (SELECT end_date FROM dates)
      AND tr.success = true
      AND tr.type NOT IN ('delegatecall', 'staticcall')
      AND (tr."to" = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
           OR tr."from" = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49)
    GROUP BY p.week_end
)

-- BOTTO flows via ERC20 transfers
, botto_flows AS (
    SELECT
          p.week_end
        , SUM(CASE WHEN t."to" = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
                   THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as botto_net
    FROM erc20_ethereum.evt_Transfer t
    JOIN prices p ON t.evt_block_time >= p.week_start AND t.evt_block_time < p.week_end
    WHERE t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND t.evt_block_time >= (SELECT start_date FROM dates)
      AND t.evt_block_time < (SELECT end_date FROM dates)
      AND (t."to" = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
           OR t."from" = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49)
    GROUP BY p.week_end
)

SELECT
      p.week_end
    , ROUND(COALESCE(ef.eth_inflow, 0), 4) as eth_inflow
    , ROUND(COALESCE(ef.eth_outflow, 0), 4) as eth_outflow
    , ROUND(COALESCE(ef.eth_inflow, 0) - COALESCE(ef.eth_outflow, 0), 4) as eth_net
    , ROUND(SUM(COALESCE(ef.eth_inflow, 0) - COALESCE(ef.eth_outflow, 0))
            OVER (ORDER BY p.week_end ASC), 4) as eth_balance
    , ROUND(SUM(COALESCE(ef.eth_inflow, 0) - COALESCE(ef.eth_outflow, 0))
            OVER (ORDER BY p.week_end ASC) * p.eth_price, 2) as eth_balance_usd
    , ROUND(COALESCE(SUM(bf.botto_net) OVER (ORDER BY p.week_end ASC), 0), 4) as botto_balance
FROM prices p
LEFT JOIN eth_flows ef ON ef.week_end = p.week_end
LEFT JOIN botto_flows bf ON bf.week_end = p.week_end
ORDER BY p.week_end ASC
