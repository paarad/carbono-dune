-- ============================================================
-- BOTTO DASHBOARD: BOTTO Burns & Token Price
-- ============================================================
-- Chart: Dual-axis line chart
-- Left axis: weekly_botto_burnt / cumulative_botto_burnt
-- Right axis: botto_price
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
        , MIN(botto.price) as botto_price
        , MIN(eth.price) / MIN(botto.price) as eth_to_botto
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

, botto_burns AS (
    SELECT
          p.week_end
        , SUM(bb.value * power(10, -18)) as botto_burnt
    FROM botto_ethereum.Botto_evt_Transfer bb
    JOIN prices p
        ON bb.evt_block_time >= p.week_start AND bb.evt_block_time < p.week_end
    WHERE bb.evt_block_time >= (SELECT start_date FROM dates)
    AND   bb.evt_block_time < (SELECT end_date FROM dates)
    AND contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
    AND "from" = 0x39c0aa77b2f4283bc5dd6b2bc707c3a6bc025391
    AND "to" = 0x000000000000000000000000000000000000dead
    GROUP BY p.week_end
)

SELECT
      p.week_end
    , p.botto_price
    , p.eth_to_botto
    , ROUND(COALESCE(bb.botto_burnt, 0), 4) as weekly_botto_burnt
    , ROUND(SUM(COALESCE(bb.botto_burnt, 0)) OVER (ORDER BY p.week_end ASC), 4) as cumulative_botto_burnt
FROM prices p
LEFT JOIN botto_burns bb ON bb.week_end = p.week_end
ORDER BY p.week_end ASC
