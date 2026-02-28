-- ============================================================
-- BOTTO DASHBOARD: DEX Trading Volume (Ethereum + Base)
-- ============================================================
-- Charts:
--   1. Bar: weekly volume_usd by chain
--   2. Line: cumulative_volume_usd
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
        AND botto.blockchain = 'ethereum'
        AND eth.contract_address = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
        AND eth.blockchain = 'ethereum'
        AND botto.minute >= (SELECT start_date + INTERVAL '7' DAY FROM dates)
        AND botto.minute <= (SELECT end_date FROM dates)
        AND day_of_week(botto.minute) = 2
        AND hour(botto.minute) = 22
        AND minute(botto.minute) = 0
)

-- BOTTO trades on Ethereum
, eth_trades AS (
    SELECT
          p.week_end
        , COUNT(*) as trade_count
        , ROUND(SUM(COALESCE(d.amount_usd, 0)), 2) as volume_usd
    FROM dex.trades d
    JOIN prices p ON d.block_time >= p.week_start AND d.block_time < p.week_end
    WHERE d.blockchain = 'ethereum'
      AND d.block_time >= (SELECT start_date FROM dates)
      AND d.block_time < (SELECT end_date FROM dates)
      AND (d.token_bought_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
           OR d.token_sold_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba)
    GROUP BY p.week_end
)

-- BOTTO trades on Base
, base_trades AS (
    SELECT
          p.week_end
        , COUNT(*) as trade_count
        , ROUND(SUM(COALESCE(d.amount_usd, 0)), 2) as volume_usd
    FROM dex.trades d
    JOIN prices p ON d.block_time >= p.week_start AND d.block_time < p.week_end
    WHERE d.blockchain = 'base'
      AND d.block_time >= (SELECT start_date FROM dates)
      AND d.block_time < (SELECT end_date FROM dates)
      AND (d.token_bought_address = 0x24914cb6bd01e6a0cf2a9c0478e33c25926e6a0c
           OR d.token_sold_address = 0x24914cb6bd01e6a0cf2a9c0478e33c25926e6a0c)
    GROUP BY p.week_end
)

SELECT
      p.week_end
    , COALESCE(et.trade_count, 0) as eth_trade_count
    , COALESCE(et.volume_usd, 0) as eth_volume_usd
    , COALESCE(bt.trade_count, 0) as base_trade_count
    , COALESCE(bt.volume_usd, 0) as base_volume_usd
    , COALESCE(et.trade_count, 0) + COALESCE(bt.trade_count, 0) as total_trade_count
    , ROUND(COALESCE(et.volume_usd, 0) + COALESCE(bt.volume_usd, 0), 2) as total_volume_usd
    , ROUND(SUM(COALESCE(et.volume_usd, 0) + COALESCE(bt.volume_usd, 0))
            OVER (ORDER BY p.week_end ASC), 2) as cumulative_volume_usd
FROM prices p
LEFT JOIN eth_trades et ON et.week_end = p.week_end
LEFT JOIN base_trades bt ON bt.week_end = p.week_end
ORDER BY p.week_end ASC
