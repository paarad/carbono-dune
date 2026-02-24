-- ============================================================
-- BOTTO DASHBOARD: Token Supply Breakdown
-- ============================================================
-- Chart: Stacked Area
-- X-axis: week_end
-- Y-series: burned, gov_staking, uni_v2_lp, uni_v3_lp,
--           rewards_wallet, liquidity_mining, circulating
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

-- Track net BOTTO flows per key address per week
, botto_flows AS (
    SELECT
          p.week_end
        , SUM(CASE WHEN t."to" = 0x000000000000000000000000000000000000dead THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0x000000000000000000000000000000000000dead THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as burned_net
        , SUM(CASE WHEN t."to" = 0x19cd3998f106ecc40ee7668c19c47e18b491e8a6 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0x19cd3998f106ecc40ee7668c19c47e18b491e8a6 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as gov_staking_net
        , SUM(CASE WHEN t."to" = 0x9ff68f61ca5eb0c6606dc517a9d44001e564bb66 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0x9ff68f61ca5eb0c6606dc517a9d44001e564bb66 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as uni_v2_lp_net
        , SUM(CASE WHEN t."to" = 0xd60dc6571e477fb2d96df02efd5fba9c54a4e998 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0xd60dc6571e477fb2d96df02efd5fba9c54a4e998 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as uni_v3_lp_net
        , SUM(CASE WHEN t."to" = 0x93298241417a63469b6f8f080b4878749acb4c47 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0x93298241417a63469b6f8f080b4878749acb4c47 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as rewards_wallet_net
        , SUM(CASE WHEN t."to" = 0xf8515cae6915838543bcd7756f39268ce8f853fd THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0xf8515cae6915838543bcd7756f39268ce8f853fd THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as liquidity_mining_net
    FROM erc20_ethereum.evt_Transfer t
    JOIN prices p ON t.evt_block_time >= p.week_start AND t.evt_block_time < p.week_end
    WHERE t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND t.evt_block_time >= (SELECT start_date FROM dates)
      AND t.evt_block_time < (SELECT end_date FROM dates)
      AND (
          t."to" IN (
              0x000000000000000000000000000000000000dead,
              0x19cd3998f106ecc40ee7668c19c47e18b491e8a6,
              0x9ff68f61ca5eb0c6606dc517a9d44001e564bb66,
              0xd60dc6571e477fb2d96df02efd5fba9c54a4e998,
              0x93298241417a63469b6f8f080b4878749acb4c47,
              0xf8515cae6915838543bcd7756f39268ce8f853fd
          )
          OR t."from" IN (
              0x000000000000000000000000000000000000dead,
              0x19cd3998f106ecc40ee7668c19c47e18b491e8a6,
              0x9ff68f61ca5eb0c6606dc517a9d44001e564bb66,
              0xd60dc6571e477fb2d96df02efd5fba9c54a4e998,
              0x93298241417a63469b6f8f080b4878749acb4c47,
              0xf8515cae6915838543bcd7756f39268ce8f853fd
          )
      )
    GROUP BY p.week_end
)

SELECT
      p.week_end
    , ROUND(COALESCE(SUM(bf.burned_net) OVER (ORDER BY p.week_end ASC), 0), 4) as burned
    , ROUND(COALESCE(SUM(bf.gov_staking_net) OVER (ORDER BY p.week_end ASC), 0), 4) as gov_staking
    , ROUND(COALESCE(SUM(bf.uni_v2_lp_net) OVER (ORDER BY p.week_end ASC), 0), 4) as uni_v2_lp
    , ROUND(COALESCE(SUM(bf.uni_v3_lp_net) OVER (ORDER BY p.week_end ASC), 0), 4) as uni_v3_lp
    , ROUND(COALESCE(SUM(bf.rewards_wallet_net) OVER (ORDER BY p.week_end ASC), 0), 4) as rewards_wallet
    , ROUND(COALESCE(SUM(bf.liquidity_mining_net) OVER (ORDER BY p.week_end ASC), 0), 4) as liquidity_mining
    , ROUND(100000000
        - COALESCE(SUM(bf.burned_net) OVER (ORDER BY p.week_end ASC), 0)
        - COALESCE(SUM(bf.gov_staking_net) OVER (ORDER BY p.week_end ASC), 0)
        - COALESCE(SUM(bf.uni_v2_lp_net) OVER (ORDER BY p.week_end ASC), 0)
        - COALESCE(SUM(bf.uni_v3_lp_net) OVER (ORDER BY p.week_end ASC), 0)
        - COALESCE(SUM(bf.rewards_wallet_net) OVER (ORDER BY p.week_end ASC), 0)
        - COALESCE(SUM(bf.liquidity_mining_net) OVER (ORDER BY p.week_end ASC), 0)
      , 4) as circulating
FROM prices p
LEFT JOIN botto_flows bf ON bf.week_end = p.week_end
ORDER BY p.week_end ASC
