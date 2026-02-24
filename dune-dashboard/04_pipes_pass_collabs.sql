-- ============================================================
-- BOTTO DASHBOARD: Non-Art Revenue (Pipes, Access Pass, Collabs)
-- ============================================================
-- Chart: Grouped bar chart
-- X-axis: week_end | Y-axis: revenue | Color: source
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

-- Pipe primary (redeem calls)
, pipe_primary AS (
    SELECT p.week_end,
        SUM(cast(json_extract_scalar(ps.permit_, '$.minimumPrice') as double) * power(10, -18)) as revenue,
        COUNT(ps.call_tx_hash) as quantity
    FROM botto_ethereum.CeciNestPasUnBotto_call_redeem ps
    JOIN prices p ON ps.call_block_time >= p.week_start AND ps.call_block_time < p.week_end
    WHERE ps.call_block_time >= (SELECT start_date FROM dates)
      AND ps.call_block_time < (SELECT end_date FROM dates) AND ps.call_success = true
    GROUP BY p.week_end
)

-- Pipe secondary (marketplace royalties)
, pipe_secondary AS (
    SELECT p.week_end,
        SUM(pr.amount_original) as sales,
        SUM(pr.royalty_fee_amount) as revenue,
        SUM(pr.number_of_items) as quantity
    FROM nft.trades pr
    JOIN prices p ON pr.block_time >= p.week_start AND pr.block_time < p.week_end
    WHERE pr.block_time >= (SELECT start_date FROM dates) AND pr.block_time < (SELECT end_date FROM dates)
      AND pr.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
      AND pr.currency_symbol IN ('ETH', 'WETH')
    GROUP BY p.week_end
)

-- Access Pass primary
, access_pass_primary AS (
    SELECT p.week_end,
        SUM(round((app.value * power(10, -18)),2)) as revenue,
        cast(SUM(round(round((app.value * power(10, -18)),4) / 0.03,0)) as integer) as quantity
    FROM ethereum.transactions app
    JOIN prices p ON app.block_time >= p.week_start AND app.block_time < p.week_end
    WHERE app.block_time >= (SELECT start_date FROM dates) AND app.block_time < (SELECT end_date FROM dates)
      AND "to" = 0x6802df79bcbbf019fe5cb366ff25720d1365cfd3
      AND app.success = true AND app.value <> 0
    GROUP BY p.week_end
)

-- Access Pass secondary (royalties)
, access_pass_secondary AS (
    SELECT p.week_end,
        SUM(aps.royalty_fee_amount) as revenue,
        cast(SUM(aps.number_of_items) as integer) as quantity
    FROM nft.fees aps
    JOIN prices p ON aps.block_time >= p.week_start AND aps.block_time < p.week_end
    WHERE aps.block_time >= (SELECT start_date FROM dates) AND aps.block_time < (SELECT end_date FROM dates)
      AND aps.nft_contract_address = 0x6802df79bcbbf019fe5cb366ff25720d1365cfd3
      AND 0x9b627af2a48f2e07beeeb82141e3ac6e231326bf NOT IN (aps.tx_from, aps.tx_to)
      AND aps.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
      AND aps.royalty_fee_currency_symbol IN ('ETH','WETH')
    GROUP BY p.week_end
)

-- Collaborations
, collaborations AS (
    SELECT p.week_end, bc.value / 1e+18 as revenue, 1 as quantity
    FROM ethereum.traces bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.tx_hash = 0x13c973087e5d0577b7edee854364285eaee949c3f8bcc8fd500f79e9f9844fea
      AND bc.block_number = 16887424
      AND bc.to = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    UNION ALL
    SELECT p.week_end, bc.royalty_fee_amount, 1
    FROM seaport_ethereum.trades bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address = 0xdcb1c3275ca97f148f6da1b0ee85bcb75cc9c5a4
    UNION ALL
    SELECT p.week_end, SUM(bc.amount_original * 0.85 / 2), cast(SUM(bc.number_of_items) as integer)
    FROM nft.trades bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address = 0x1b6745f9a95b9ee195cff963dd6ef03dbf486257
      AND cast(bc.token_id as varchar) = '3'
      AND bc.tx_from = 0xfcbe1f6ec1c26c8f48bd835d650a3383ea1797c2
    GROUP BY p.week_end
    UNION ALL
    -- Geometric Fluidity, Algorithmic Evolution, Genesis Special Editions
    SELECT p.week_end, SUM(bc.royalty_fee_amount), cast(SUM(bc.number_of_items) as integer)
    FROM nft.trades bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address IN (
          0x16e9cfda70c72ef12c6a96ba4261bea3d2865044,
          0x5d6a7196d14408278d40ffdfe4cb697a6799ca88,
          0x4a075606591369c41d7e90d13a1e094b3058683e
      )
      AND bc.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    GROUP BY p.week_end
    UNION ALL
    -- Pepe's Multidimensional Leap
    SELECT p.week_end, SUM(bc.royalty_fee_amount), 1
    FROM nft.trades bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address = 0xe70659b717112ac4e14284d0db2f5d5703df8e43
      AND bc.token_id = 306
      AND bc.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    GROUP BY p.week_end
    UNION ALL
    -- Alchemist's Playroom (1155) — 50 tokens in Grails V (Artist: Botto)
    SELECT p.week_end, SUM(bc.royalty_fee_amount), cast(SUM(bc.number_of_items) as integer)
    FROM nft.trades bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address = 0x92a50fe6ede411bd26e171b97472e24d245349b8
      AND bc.token_id IN (3,21,49,61,76,78,83,93,216,238,255,258,266,269,273,278,279,286,293,
          304,314,327,328,334,343,351,360,373,376,379,385,390,393,394,395,397,
          400,401,404,407,409,411,412,413,416,417,418,419,420,421)
      AND bc.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    GROUP BY p.week_end
)

-- Output in long format for chart grouping
SELECT week_end, source, ROUND(revenue, 4) as revenue, quantity FROM (
    SELECT p.week_end, 'Pipe Primary' as source,
        COALESCE(pp.revenue, 0) as revenue, COALESCE(pp.quantity, 0) as quantity
    FROM prices p LEFT JOIN pipe_primary pp ON pp.week_end = p.week_end
    WHERE COALESCE(pp.revenue, 0) > 0

    UNION ALL
    SELECT p.week_end, 'Pipe Secondary',
        COALESCE(ps.revenue, 0), COALESCE(ps.quantity, 0)
    FROM prices p LEFT JOIN pipe_secondary ps ON ps.week_end = p.week_end
    WHERE COALESCE(ps.revenue, 0) > 0

    UNION ALL
    SELECT p.week_end, 'Access Pass Primary',
        COALESCE(app.revenue, 0), COALESCE(app.quantity, 0)
    FROM prices p LEFT JOIN access_pass_primary app ON app.week_end = p.week_end
    WHERE COALESCE(app.revenue, 0) > 0

    UNION ALL
    SELECT p.week_end, 'Access Pass Secondary',
        COALESCE(aps.revenue, 0), COALESCE(aps.quantity, 0)
    FROM prices p LEFT JOIN access_pass_secondary aps ON aps.week_end = p.week_end
    WHERE COALESCE(aps.revenue, 0) > 0

    UNION ALL
    SELECT week_end, 'Collaborations', SUM(revenue), SUM(quantity)
    FROM collaborations
    GROUP BY week_end
) sources
ORDER BY week_end ASC, source
