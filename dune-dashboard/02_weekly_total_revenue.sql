-- ============================================================
-- BOTTO DASHBOARD: Weekly Total Revenue + Treasury + Rewards
-- ============================================================
-- Charts:
--   1. Bar chart: weekly total_revenue by source (art/pipes/pass/collabs)
--   2. Area chart: cumulative_revenue
--   3. Stacked area: treasury_allocation + active_rewards + retroactive_rewards
-- X-axis: week_end for all
-- ============================================================

WITH dates AS (
    SELECT
        TIMESTAMP '2021-10-19 22:00:00' as start_date,
        current_timestamp as end_date
)

, prices AS (
    SELECT
          week_end
        , week_start
        , row_number() OVER (ORDER BY week_end ASC) as week_number
    FROM (
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
)

, superrare_sales_raw AS (
    SELECT evt_block_time as block_time, cast(_amount as double) / 1e18 as amount_original,
           _seller as seller, _originContract as nft_contract_address, _tokenId as token_id
    FROM superrare_ethereum.SuperRareBazaar_evt_Sold
    UNION ALL
    SELECT evt_block_time, cast(_amount as double) / 1e18, _seller, _contractAddress, _tokenId
    FROM superrare_ethereum.SuperRareBazaar_evt_AuctionSettled
    UNION ALL
    SELECT evt_block_time, cast(_amount as double) / 1e18, _seller, _originContract, _tokenId
    FROM superrare_ethereum.SuperRareMarketAuction_evt_Sold
    UNION ALL
    SELECT evt_block_time, cast(_amount as double) / 1e18, _seller, _originContract, _tokenId
    FROM superrare_ethereum.SuperRareMarketAuction_evt_AcceptBid
    UNION ALL
    SELECT evt_block_time, cast(_amount as double) / 1e18, _seller, contract_address, _tokenId
    FROM superrare_ethereum.SuperRare_evt_Sold
    UNION ALL
    SELECT evt_block_time, cast(_amount as double) / 1e18, _seller, _contractAddress, _tokenId
    FROM superrare_ethereum.SuperRareAuctionHouse_evt_AuctionSettled
)

-- Dedup only Botto wallet sales (1 primary per token), keep all secondary sales
, superrare_sales AS (
    SELECT block_time, amount_original, seller, nft_contract_address, token_id
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY nft_contract_address, token_id, seller ORDER BY block_time ASC) as rn
        FROM superrare_sales_raw
        WHERE seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    ) t
    WHERE rn = 1
    UNION ALL
    SELECT block_time, amount_original, seller, nft_contract_address, token_id
    FROM superrare_sales_raw
    WHERE seller NOT IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
)

-- SuperRare BatchOfferCreator sales (not captured by nft.trades)
-- Get sale metadata from event, ETH amount from transaction value
, batch_offer_events AS (
    SELECT
        l.block_time,
        l.block_number,
        l.tx_hash,
        bytearray_substring(l.topic1, 13, 20) as seller,
        bytearray_substring(l.topic3, 13, 20) as nft_contract_address,
        bytearray_to_uint256(bytearray_substring(l.data, 1, 32)) as token_id
    FROM ethereum.logs l
    WHERE l.topic0 = 0x25d87e12d2953b43b0140bdfc8a4fa389293a8d350e9becd3e21d6646620fa72
      AND bytearray_substring(l.topic3, 13, 20) IN (
          0xb932a70a57673d89f4acffbe830e8ed7f75fb9e0,  -- Genesis (SuperRare shared)
          0xa4dc93da01458d38f691db5c98e9157891febe86,  -- Fragmentation
          0xbdf4f17b7d638d7d3e5dcadf27e812b07b2b5c9e   -- Paradox
      )
)
, batch_offer_sales AS (
    SELECT
        b.block_time,
        CAST(tx.value AS double) / 1e18 as amount_original,
        b.seller,
        b.nft_contract_address,
        b.token_id
    FROM batch_offer_events b
    JOIN ethereum.transactions tx
        ON tx.hash = b.tx_hash
        AND tx.block_number = b.block_number
)

, all_art_sales AS (
    -- Genesis
    SELECT block_time,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END as revenue,
        'Genesis' as period
    FROM nft.trades
    WHERE nft_contract_address = 0xb932a70a57673d89f4acffbe830e8ed7f75fb9e0
      AND cast(token_id as varchar) IN (
          '29715','29922','30114','30298','30443','30639','30887','31057','31200','31352','31447',
          '31546','31704','31887','32068','32242','32457','32619','32737','33018','33163','33332',
          '33501','33637','33754','33879','34066','34231','34399','34540','34684','34910','35069',
          '35208','35353','35482','35616','35769','35934','36127','36315','36525','36702','36905',
          '37149','37380','37657','37877','38050','38335','38615','38913')
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
      AND tx_hash NOT IN (SELECT tx_hash FROM batch_offer_events)
    UNION ALL
    -- Fragmentation
    SELECT block_time,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        'Fragmentation'
    FROM nft.trades
    WHERE nft_contract_address = 0xa4dc93da01458d38f691db5c98e9157891febe86
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
      AND tx_hash NOT IN (SELECT tx_hash FROM batch_offer_events)
    UNION ALL
    -- Paradox
    SELECT block_time,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        'Paradox'
    FROM nft.trades
    WHERE nft_contract_address = 0xbdf4f17b7d638d7d3e5dcadf27e812b07b2b5c9e
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
      AND tx_hash NOT IN (SELECT tx_hash FROM batch_offer_events)
    UNION ALL
    -- Genesis (batch offers)
    SELECT block_time,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        'Genesis'
    FROM batch_offer_sales
    WHERE nft_contract_address = 0xb932a70a57673d89f4acffbe830e8ed7f75fb9e0
      AND cast(token_id as varchar) IN (
          '29715','29922','30114','30298','30443','30639','30887','31057','31200','31352','31447',
          '31546','31704','31887','32068','32242','32457','32619','32737','33018','33163','33332',
          '33501','33637','33754','33879','34066','34231','34399','34540','34684','34910','35069',
          '35208','35353','35482','35616','35769','35934','36127','36315','36525','36702','36905',
          '37149','37380','37657','37877','38050','38335','38615','38913')
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
    UNION ALL
    -- Fragmentation (batch offers)
    SELECT block_time,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        'Fragmentation'
    FROM batch_offer_sales
    WHERE nft_contract_address = 0xa4dc93da01458d38f691db5c98e9157891febe86
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
    UNION ALL
    -- Paradox (batch offers)
    SELECT block_time,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        'Paradox'
    FROM batch_offer_sales
    WHERE nft_contract_address = 0xbdf4f17b7d638d7d3e5dcadf27e812b07b2b5c9e
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
    UNION ALL
    -- Rebellion
    SELECT block_time,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        'Rebellion'
    FROM nft.trades
    WHERE nft_contract_address = 0x1c7576619032eaf8b8a938c352e535bba92a366c
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
    UNION ALL
    -- Absurdism
    SELECT block_time,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        'Absurdism'
    FROM nft.trades
    WHERE nft_contract_address = 0x47542736c9d1086dc87cc45138b2d57ec79eafa3
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
    UNION ALL
    -- 2024 Contract (Interstice, Temporal Echoes, Morphogenesis, Synthetic Histories)
    SELECT block_time,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        CASE WHEN token_id >= 1 AND token_id <= 13 THEN 'Interstice'
             WHEN token_id > 13 AND token_id <= 26 THEN 'Temporal Echoes'
             WHEN token_id > 26 AND token_id <= 39 THEN 'Morphogenesis'
             WHEN token_id > 39 AND token_id <= 52 THEN 'Synthetic Histories' END
    FROM nft.trades
    WHERE nft_contract_address = 0xca53bb6cdfcd5bf437bf4ac6d17c3b0e67d8a83e
      AND token_id >= 1 AND token_id <= 52
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
    UNION ALL
    -- 2025 Contract (Cosmic Garden, Liminal Thresholds, Semantic Drift, Attention Economy)
    SELECT block_time,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        CASE WHEN token_id >= 1 AND token_id <= 13 THEN 'Cosmic Garden'
             WHEN token_id > 13 AND token_id <= 26 THEN 'Liminal Thresholds'
             WHEN token_id > 26 AND token_id <= 39 THEN 'Semantic Drift'
             WHEN token_id > 39 AND token_id <= 52 THEN 'Attention Economy' END
    FROM nft.trades
    WHERE nft_contract_address = 0x66cd3ede22a25eef3cc8799381b99b1d4f0983f8
      AND token_id >= 1 AND token_id <= 52
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
    UNION ALL
    -- 2026 Contract (Collapse Aesthetics)
    SELECT block_time,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        'Collapse Aesthetics'
    FROM nft.trades
    WHERE nft_contract_address = 0x3cb787d48c34cca29653f54efc9112b4134b879d
      AND token_id >= 1 AND token_id <= 13
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
)

-- Aggregate art revenue per week (total + early-only for treasury logic)
, art_weekly AS (
    SELECT
          p.week_end
        , ROUND(SUM(a.revenue), 4) as total_art_revenue
        , ROUND(SUM(CASE WHEN a.period IN ('Genesis', 'Fragmentation') THEN a.revenue ELSE 0 END), 4) as early_art_revenue
    FROM all_art_sales a
    JOIN prices p ON a.block_time >= p.week_start AND a.block_time < p.week_end
    WHERE a.period IS NOT NULL
    GROUP BY p.week_end
)

, pipe_primary AS (
    SELECT p.week_end,
        SUM(cast(json_extract_scalar(ps.permit_, '$.minimumPrice') as double) * power(10, -18)) as revenue
    FROM botto_ethereum.CeciNestPasUnBotto_call_redeem ps
    JOIN prices p ON ps.call_block_time >= p.week_start AND ps.call_block_time < p.week_end
    WHERE ps.call_block_time >= (SELECT start_date FROM dates)
      AND ps.call_block_time < (SELECT end_date FROM dates) AND ps.call_success = true
    GROUP BY p.week_end
)

, pipe_secondary AS (
    SELECT p.week_end, SUM(pr.royalty_fee_amount) as revenue
    FROM nft.trades pr
    JOIN prices p ON pr.block_time >= p.week_start AND pr.block_time < p.week_end
    WHERE pr.block_time >= (SELECT start_date FROM dates) AND pr.block_time < (SELECT end_date FROM dates)
      AND pr.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
      AND pr.currency_symbol IN ('ETH', 'WETH')
    GROUP BY p.week_end
)

, access_pass_primary AS (
    SELECT p.week_end, SUM(round((app.value * power(10, -18)),2)) as revenue
    FROM ethereum.transactions app
    JOIN prices p ON app.block_time >= p.week_start AND app.block_time < p.week_end
    WHERE app.block_time >= (SELECT start_date FROM dates) AND app.block_time < (SELECT end_date FROM dates)
      AND "to" = 0x6802df79bcbbf019fe5cb366ff25720d1365cfd3
      AND app.success = true AND app.value <> 0
    GROUP BY p.week_end
)

, access_pass_secondary AS (
    SELECT p.week_end, SUM(aps.royalty_fee_amount) as revenue
    FROM nft.fees aps
    JOIN prices p ON aps.block_time >= p.week_start AND aps.block_time < p.week_end
    WHERE aps.block_time >= (SELECT start_date FROM dates) AND aps.block_time < (SELECT end_date FROM dates)
      AND aps.nft_contract_address = 0x6802df79bcbbf019fe5cb366ff25720d1365cfd3
      AND 0x9b627af2a48f2e07beeeb82141e3ac6e231326bf NOT IN (aps.tx_from, aps.tx_to)
      AND aps.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
      AND aps.royalty_fee_currency_symbol IN ('ETH','WETH')
    GROUP BY p.week_end
)

, collaborations_weekly AS (
    SELECT p.week_end, bc.value / 1e+18 as revenue
    FROM ethereum.traces bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.tx_hash = 0x13c973087e5d0577b7edee854364285eaee949c3f8bcc8fd500f79e9f9844fea
      AND bc.block_number = 16887424
      AND bc.to = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    UNION ALL
    SELECT p.week_end, bc.royalty_fee_amount
    FROM seaport_ethereum.trades bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address = 0xdcb1c3275ca97f148f6da1b0ee85bcb75cc9c5a4
    UNION ALL
    SELECT p.week_end, SUM(bc.amount_original * 0.85 / 2)
    FROM nft.trades bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address = 0x1b6745f9a95b9ee195cff963dd6ef03dbf486257
      AND cast(bc.token_id as varchar) = '3'
      AND bc.tx_from = 0xfcbe1f6ec1c26c8f48bd835d650a3383ea1797c2
    GROUP BY p.week_end
    UNION ALL
    -- Geometric Fluidity, Algorithmic Evolution, Genesis Special Editions
    SELECT p.week_end, SUM(bc.royalty_fee_amount)
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
    SELECT p.week_end, SUM(bc.royalty_fee_amount)
    FROM nft.trades bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address = 0xe70659b717112ac4e14284d0db2f5d5703df8e43
      AND bc.token_id = 306
      AND bc.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    GROUP BY p.week_end
    UNION ALL
    -- Alchemist's Playroom (1155) — 50 tokens in Grails V (Artist: Botto)
    SELECT p.week_end, SUM(bc.royalty_fee_amount)
    FROM nft.trades bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address = 0x92a50fe6ede411bd26e171b97472e24d245349b8
      AND bc.token_id IN (3,21,49,61,76,78,83,93,216,238,255,258,266,269,273,278,279,286,293,
          304,314,327,328,334,343,351,360,373,376,379,385,390,393,394,395,397,
          400,401,404,407,409,411,412,413,416,417,418,419,420,421)
      AND bc.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    GROUP BY p.week_end
    UNION ALL
    -- Pepe collab (10.89 ETH to botto.eth)
    SELECT p.week_end, CAST(bc.value AS DOUBLE) / 1e18
    FROM ethereum.traces bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.tx_hash = 0x39430d2d1be3e3d03e0350ab0414e520b440e231dbfc29426fdf4e410040bd23
      AND bc.block_number = 20876061
      AND bc."to" = 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c
      AND bc.value > UINT256 '0'
    UNION ALL
    -- Botto P5 ETH portion (150.829 ETH)
    SELECT p.week_end, CAST(bc.value AS DOUBLE) / 1e18
    FROM ethereum.traces bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.tx_hash = 0xb6b00f67e4e08c9017010f28fd1acfc4ff564cdb1b9cd6c9728b586c559778bb
      AND bc.block_number = 21973515
      AND bc."to" = 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c
      AND bc.value > UINT256 '0'
    UNION ALL
    -- Botto P5 ETH portion (54.453 ETH)
    SELECT p.week_end, CAST(bc.value AS DOUBLE) / 1e18
    FROM ethereum.traces bc
    JOIN prices p ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.tx_hash = 0xdb7250925cc12fdf6a78a47b225b668581b19c5c184639164b58ecdc6853233b
      AND bc.block_number = 21932218
      AND bc."to" = 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c
      AND bc.value > UINT256 '0'
    UNION ALL
    -- Botto P5 USDC portion (52,597.67 USDC converted to ETH at tx time)
    SELECT p.week_end,
        CAST(t.value AS DOUBLE) / 1e6 / MAX(ep.price)
    FROM erc20_ethereum.evt_Transfer t
    JOIN prices p ON t.evt_block_time >= p.week_start AND t.evt_block_time < p.week_end
    JOIN prices.usd ep
        ON ep.contract_address = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
        AND ep.minute = date_trunc('minute', t.evt_block_time)
    WHERE t.evt_tx_hash = 0x53a0f2b5b63e628484962572270497633be244452a412623d68093078c8a4d78
      AND t.contract_address = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
    GROUP BY p.week_end, t.value
)

, botto_burns AS (
    SELECT p.week_end, SUM(bb.value * power(10, -18)) as botto_burnt
    FROM botto_ethereum.Botto_evt_Transfer bb
    JOIN prices p ON bb.evt_block_time >= p.week_start AND bb.evt_block_time < p.week_end
    WHERE bb.evt_block_time >= (SELECT start_date FROM dates) AND bb.evt_block_time < (SELECT end_date FROM dates)
      AND contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND "to" = 0x000000000000000000000000000000000000dead
    GROUP BY p.week_end
)

-- Combine all revenue sources
, weekly_combined AS (
    SELECT
          p.week_end
        , p.week_start
        , p.week_number
        , COALESCE(art.total_art_revenue, 0) as art_revenue
        , COALESCE(art.early_art_revenue, 0) as early_art_revenue
        , ROUND(COALESCE(pp.revenue, 0), 4) as pipe_primary_revenue
        , ROUND(COALESCE(ps.revenue, 0), 4) as pipe_secondary_revenue
        , ROUND(COALESCE(app.revenue, 0), 4) as pass_primary_revenue
        , ROUND(COALESCE(aps.revenue, 0), 4) as pass_secondary_revenue
        , ROUND(COALESCE(cw.revenue, 0), 4) as collab_revenue
        , ROUND(COALESCE(bb.botto_burnt, 0), 4) as botto_burnt
    FROM prices p
    LEFT JOIN art_weekly art ON art.week_end = p.week_end
    LEFT JOIN pipe_primary pp ON pp.week_end = p.week_end
    LEFT JOIN pipe_secondary ps ON ps.week_end = p.week_end
    LEFT JOIN access_pass_primary app ON app.week_end = p.week_end
    LEFT JOIN access_pass_secondary aps ON aps.week_end = p.week_end
    LEFT JOIN (SELECT week_end, SUM(revenue) as revenue FROM collaborations_weekly GROUP BY week_end) cw ON cw.week_end = p.week_end
    LEFT JOIN botto_burns bb ON bb.week_end = p.week_end
)

, weekly_calcs AS (
    SELECT
          week_end, week_start, week_number
        , art_revenue
        , pipe_primary_revenue + pipe_secondary_revenue as pipe_revenue
        , pass_primary_revenue + pass_secondary_revenue as pass_revenue
        , collab_revenue
        , botto_burnt
        -- Total revenue
        , ROUND(art_revenue + pipe_primary_revenue + pipe_secondary_revenue
                + pass_primary_revenue + pass_secondary_revenue + collab_revenue, 4) as total_revenue
        -- Treasury allocation (time-based logic from original)
        , CASE
            WHEN week_start < TIMESTAMP '2022-04-19 22:00:00' THEN 0
            WHEN week_start >= TIMESTAMP '2022-04-19 22:00:00' AND week_start < TIMESTAMP '2022-11-01 22:00:00'
                THEN ROUND(early_art_revenue + collab_revenue
                     + pipe_primary_revenue + pipe_secondary_revenue
                     + pass_primary_revenue + pass_secondary_revenue, 4)
            WHEN week_start >= TIMESTAMP '2022-11-01 22:00:00'
                THEN ROUND((art_revenue + collab_revenue
                     + pipe_primary_revenue + pipe_secondary_revenue
                     + pass_primary_revenue + pass_secondary_revenue) * 0.5, 4)
          END as treasury_allocation
        -- Active rewards
        , CASE
            WHEN week_start < TIMESTAMP '2022-11-01 22:00:00' THEN 0
            WHEN week_start >= TIMESTAMP '2022-11-01 22:00:00' AND week_start < TIMESTAMP '2023-05-30 22:00:00'
                THEN ROUND((early_art_revenue + collab_revenue
                     + pipe_primary_revenue + pipe_secondary_revenue
                     + pass_primary_revenue + pass_secondary_revenue) * 0.25, 4)
            WHEN week_start >= TIMESTAMP '2023-05-30 22:00:00'
                THEN ROUND((art_revenue + collab_revenue
                     + pipe_primary_revenue + pipe_secondary_revenue
                     + pass_primary_revenue + pass_secondary_revenue) * 0.5, 4)
          END as active_rewards
        -- Retroactive rewards
        , CASE
            WHEN week_start < TIMESTAMP '2022-11-01 22:00:00' THEN 0
            WHEN week_start >= TIMESTAMP '2022-11-01 22:00:00' AND week_start < TIMESTAMP '2023-05-30 22:00:00'
                THEN ROUND((early_art_revenue + collab_revenue
                     + pipe_primary_revenue + pipe_secondary_revenue
                     + pass_primary_revenue + pass_secondary_revenue) * 0.25, 4)
            WHEN week_start >= TIMESTAMP '2023-05-30 22:00:00' THEN 0
          END as retroactive_rewards
    FROM weekly_combined
)

SELECT
      week_end
    , week_number
    , art_revenue
    , pipe_revenue
    , pass_revenue
    , collab_revenue
    , total_revenue
    , treasury_allocation
    , active_rewards
    , retroactive_rewards
    , botto_burnt
    -- Cumulative metrics (window functions)
    , ROUND(SUM(total_revenue) OVER (ORDER BY week_number ASC), 4) as cumulative_revenue
    , ROUND(SUM(active_rewards) OVER (ORDER BY week_number ASC), 4) as cumulative_active_rewards
    , ROUND(SUM(retroactive_rewards) OVER (ORDER BY week_number ASC), 4) as cumulative_retroactive_rewards
    , ROUND(SUM(botto_burnt) OVER (ORDER BY week_number ASC), 4) as cumulative_botto_burnt
FROM weekly_calcs
ORDER BY week_number ASC
