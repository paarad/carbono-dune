-- ============================================================
-- BOTTO DASHBOARD: Revenue Counters
-- ============================================================
-- Chart: Counter widgets (one per metric)
-- Covers: art revenue, pipes, pass, collabs, grand total
-- Token/protocol counters split into 05b_token_counters.sql
-- ============================================================

WITH dates AS (
    SELECT
        TIMESTAMP '2021-10-19 22:00:00' as start_date,
        current_timestamp as end_date
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
    SELECT block_time, amount_original as sales,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END as revenue,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN 'primary' ELSE 'secondary' END as sale_type,
        1 as quantity, period
    FROM (
        SELECT block_time, amount_original, seller, 'Genesis' as period
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
        SELECT block_time, amount_original, seller, 'Fragmentation'
        FROM nft.trades WHERE nft_contract_address = 0xa4dc93da01458d38f691db5c98e9157891febe86
          AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
          AND tx_hash NOT IN (SELECT tx_hash FROM batch_offer_events)
        UNION ALL
        SELECT block_time, amount_original, seller, 'Paradox'
        FROM nft.trades WHERE nft_contract_address = 0xbdf4f17b7d638d7d3e5dcadf27e812b07b2b5c9e
          AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
          AND tx_hash NOT IN (SELECT tx_hash FROM batch_offer_events)
        UNION ALL
        SELECT block_time, amount_original, seller, 'Genesis'
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
        SELECT block_time, amount_original, seller, 'Fragmentation'
        FROM batch_offer_sales WHERE nft_contract_address = 0xa4dc93da01458d38f691db5c98e9157891febe86
          AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
        UNION ALL
        SELECT block_time, amount_original, seller, 'Paradox'
        FROM batch_offer_sales WHERE nft_contract_address = 0xbdf4f17b7d638d7d3e5dcadf27e812b07b2b5c9e
          AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
    ) sr

    UNION ALL
    SELECT block_time, amount_original,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN 'primary' ELSE 'secondary' END,
        cast(number_of_items as integer), period
    FROM (
        SELECT block_time, amount_original, seller, number_of_items, 'Rebellion' as period
        FROM nft.trades WHERE nft_contract_address = 0x1c7576619032eaf8b8a938c352e535bba92a366c
          AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
        UNION ALL
        SELECT block_time, amount_original, seller, number_of_items, 'Absurdism'
        FROM nft.trades WHERE nft_contract_address = 0x47542736c9d1086dc87cc45138b2d57ec79eafa3
          AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
        UNION ALL
        SELECT block_time, amount_original, seller, number_of_items,
            CASE WHEN token_id >= 1 AND token_id <= 13 THEN 'Interstice'
                 WHEN token_id > 13 AND token_id <= 26 THEN 'Temporal Echoes'
                 WHEN token_id > 26 AND token_id <= 39 THEN 'Morphogenesis'
                 WHEN token_id > 39 AND token_id <= 52 THEN 'Synthetic Histories' END
        FROM nft.trades WHERE nft_contract_address = 0xca53bb6cdfcd5bf437bf4ac6d17c3b0e67d8a83e
          AND token_id >= 1 AND token_id <= 52
          AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
        UNION ALL
        SELECT block_time, amount_original, seller, number_of_items,
            CASE WHEN token_id >= 1 AND token_id <= 13 THEN 'Cosmic Garden'
                 WHEN token_id > 13 AND token_id <= 26 THEN 'Liminal Thresholds'
                 WHEN token_id > 26 AND token_id <= 39 THEN 'Semantic Drift'
                 WHEN token_id > 39 AND token_id <= 52 THEN 'Attention Economy' END
        FROM nft.trades WHERE nft_contract_address = 0x66cd3ede22a25eef3cc8799381b99b1d4f0983f8
          AND token_id >= 1 AND token_id <= 52
          AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
        UNION ALL
        SELECT block_time, amount_original, seller, number_of_items, 'Collapse Aesthetics'
        FROM nft.trades WHERE nft_contract_address = 0x3cb787d48c34cca29653f54efc9112b4134b879d
          AND token_id >= 1 AND token_id <= 13
          AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
    ) nt
)

, art_totals AS (
    SELECT
        ROUND(SUM(CASE WHEN sale_type = 'primary' THEN revenue ELSE 0 END), 4) as total_primary_revenue,
        ROUND(SUM(CASE WHEN sale_type = 'secondary' THEN revenue ELSE 0 END), 4) as total_secondary_revenue,
        ROUND(SUM(revenue), 4) as total_art_revenue,
        ROUND(SUM(sales), 4) as total_art_volume,
        SUM(CASE WHEN sale_type = 'primary' THEN quantity ELSE 0 END) as artworks_sold_primary,
        -- Per-period breakdowns
        ROUND(SUM(CASE WHEN period = 'Genesis' THEN revenue ELSE 0 END), 4) as genesis_revenue,
        ROUND(SUM(CASE WHEN period = 'Fragmentation' THEN revenue ELSE 0 END), 4) as fragmentation_revenue,
        ROUND(SUM(CASE WHEN period = 'Paradox' THEN revenue ELSE 0 END), 4) as paradox_revenue,
        ROUND(SUM(CASE WHEN period = 'Rebellion' THEN revenue ELSE 0 END), 4) as rebellion_revenue,
        ROUND(SUM(CASE WHEN period = 'Absurdism' THEN revenue ELSE 0 END), 4) as absurdism_revenue,
        ROUND(SUM(CASE WHEN period = 'Interstice' THEN revenue ELSE 0 END), 4) as interstice_revenue,
        ROUND(SUM(CASE WHEN period = 'Temporal Echoes' THEN revenue ELSE 0 END), 4) as temporal_echoes_revenue,
        ROUND(SUM(CASE WHEN period = 'Morphogenesis' THEN revenue ELSE 0 END), 4) as morphogenesis_revenue,
        ROUND(SUM(CASE WHEN period = 'Synthetic Histories' THEN revenue ELSE 0 END), 4) as synthetic_histories_revenue,
        ROUND(SUM(CASE WHEN period = 'Cosmic Garden' THEN revenue ELSE 0 END), 4) as cosmic_garden_revenue,
        ROUND(SUM(CASE WHEN period = 'Liminal Thresholds' THEN revenue ELSE 0 END), 4) as liminal_thresholds_revenue,
        ROUND(SUM(CASE WHEN period = 'Semantic Drift' THEN revenue ELSE 0 END), 4) as semantic_drift_revenue,
        ROUND(SUM(CASE WHEN period = 'Attention Economy' THEN revenue ELSE 0 END), 4) as attention_economy_revenue,
        ROUND(SUM(CASE WHEN period = 'Collapse Aesthetics' THEN revenue ELSE 0 END), 4) as collapse_aesthetics_revenue
    FROM all_art_sales WHERE period IS NOT NULL
)

, pipe_totals AS (
    SELECT
        ROUND(SUM(cast(json_extract_scalar(ps.permit_, '$.minimumPrice') as double) * power(10, -18)), 4) as pipe_primary,
        COUNT(ps.call_tx_hash) as pipe_primary_qty
    FROM botto_ethereum.CeciNestPasUnBotto_call_redeem ps
    WHERE ps.call_block_time >= (SELECT start_date FROM dates)
      AND ps.call_block_time < (SELECT end_date FROM dates) AND ps.call_success = true
)

, pipe_sec_totals AS (
    SELECT ROUND(SUM(pr.royalty_fee_amount), 4) as pipe_secondary
    FROM nft.trades pr
    WHERE pr.block_time >= (SELECT start_date FROM dates) AND pr.block_time < (SELECT end_date FROM dates)
      AND pr.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
      AND pr.currency_symbol IN ('ETH', 'WETH')
)

, pass_totals AS (
    SELECT ROUND(SUM(round((app.value * power(10, -18)),2)), 4) as pass_primary
    FROM ethereum.transactions app
    WHERE app.block_time >= (SELECT start_date FROM dates) AND app.block_time < (SELECT end_date FROM dates)
      AND "to" = 0x6802df79bcbbf019fe5cb366ff25720d1365cfd3 AND app.success = true AND app.value <> 0
)

, pass_sec_totals AS (
    SELECT ROUND(SUM(aps.royalty_fee_amount), 4) as pass_secondary
    FROM nft.fees aps
    WHERE aps.block_time >= (SELECT start_date FROM dates) AND aps.block_time < (SELECT end_date FROM dates)
      AND aps.nft_contract_address = 0x6802df79bcbbf019fe5cb366ff25720d1365cfd3
      AND 0x9b627af2a48f2e07beeeb82141e3ac6e231326bf NOT IN (aps.tx_from, aps.tx_to)
      AND aps.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
      AND aps.royalty_fee_currency_symbol IN ('ETH','WETH')
)

, collaborations AS (
    SELECT bc.value / 1e+18 as revenue, 1 as quantity
    FROM ethereum.traces bc
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.tx_hash = 0x13c973087e5d0577b7edee854364285eaee949c3f8bcc8fd500f79e9f9844fea
      AND bc.block_number = 16887424
      AND bc.to = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    UNION ALL
    SELECT bc.royalty_fee_amount, 1
    FROM seaport_ethereum.trades bc
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address = 0xdcb1c3275ca97f148f6da1b0ee85bcb75cc9c5a4
    UNION ALL
    SELECT SUM(bc.amount_original * 0.85 / 2), cast(SUM(bc.number_of_items) as integer)
    FROM nft.trades bc
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address = 0x1b6745f9a95b9ee195cff963dd6ef03dbf486257
      AND cast(bc.token_id as varchar) = '3'
      AND bc.tx_from = 0xfcbe1f6ec1c26c8f48bd835d650a3383ea1797c2
    UNION ALL
    -- Geometric Fluidity, Algorithmic Evolution, Genesis Special Editions
    SELECT SUM(bc.royalty_fee_amount), cast(SUM(bc.number_of_items) as integer)
    FROM nft.trades bc
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address IN (
          0x16e9cfda70c72ef12c6a96ba4261bea3d2865044,
          0x5d6a7196d14408278d40ffdfe4cb697a6799ca88,
          0x4a075606591369c41d7e90d13a1e094b3058683e
      )
      AND bc.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    UNION ALL
    -- Pepe's Multidimensional Leap
    SELECT SUM(bc.royalty_fee_amount), 1
    FROM nft.trades bc
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address = 0xe70659b717112ac4e14284d0db2f5d5703df8e43
      AND bc.token_id = 306
      AND bc.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    UNION ALL
    -- Alchemist's Playroom (1155) — 50 tokens in Grails V (Artist: Botto)
    SELECT SUM(bc.royalty_fee_amount), cast(SUM(bc.number_of_items) as integer)
    FROM nft.trades bc
    WHERE bc.block_time >= (SELECT start_date FROM dates) AND bc.block_time < (SELECT end_date FROM dates)
      AND bc.nft_contract_address = 0x92a50fe6ede411bd26e171b97472e24d245349b8
      AND bc.token_id IN (3,21,49,61,76,78,83,93,216,238,255,258,266,269,273,278,279,286,293,
          304,314,327,328,334,343,351,360,373,376,379,385,390,393,394,395,397,
          400,401,404,407,409,411,412,413,416,417,418,419,420,421)
      AND bc.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    UNION ALL
    -- Pepe collab (10.89 ETH to botto.eth)
    SELECT CAST(bc.value AS DOUBLE) / 1e18, 1
    FROM ethereum.traces bc
    WHERE bc.tx_hash = 0x39430d2d1be3e3d03e0350ab0414e520b440e231dbfc29426fdf4e410040bd23
      AND bc.block_number = 20876061
      AND bc."to" = 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c
      AND bc.value > UINT256 '0'
    UNION ALL
    -- Botto P5 ETH portion (150.829 ETH)
    SELECT CAST(bc.value AS DOUBLE) / 1e18, 1
    FROM ethereum.traces bc
    WHERE bc.tx_hash = 0xb6b00f67e4e08c9017010f28fd1acfc4ff564cdb1b9cd6c9728b586c559778bb
      AND bc.block_number = 21973515
      AND bc."to" = 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c
      AND bc.value > UINT256 '0'
    UNION ALL
    -- Botto P5 ETH portion (54.453 ETH)
    SELECT CAST(bc.value AS DOUBLE) / 1e18, 1
    FROM ethereum.traces bc
    WHERE bc.tx_hash = 0xdb7250925cc12fdf6a78a47b225b668581b19c5c184639164b58ecdc6853233b
      AND bc.block_number = 21932218
      AND bc."to" = 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c
      AND bc.value > UINT256 '0'
    UNION ALL
    -- Botto P5 USDC portion (52,597.67 USDC converted to ETH at tx time)
    SELECT CAST(t.value AS DOUBLE) / 1e6 / MAX(ep.price), 1
    FROM erc20_ethereum.evt_Transfer t
    JOIN prices.usd ep
        ON ep.contract_address = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
        AND ep.minute = date_trunc('minute', t.evt_block_time)
    WHERE t.evt_tx_hash = 0x53a0f2b5b63e628484962572270497633be244452a412623d68093078c8a4d78
      AND t.contract_address = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
    GROUP BY t.value
)

, collab_totals AS (
    SELECT ROUND(SUM(revenue), 4) as collab_revenue, SUM(quantity) as collab_quantity
    FROM collaborations
)


SELECT
    -- Headline KPIs
      art.total_art_revenue
    , art.total_primary_revenue
    , art.total_secondary_revenue
    , COALESCE(pt.pipe_primary, 0) + COALESCE(pst.pipe_secondary, 0) as total_pipe_revenue
    , COALESCE(pass.pass_primary, 0) + COALESCE(passs.pass_secondary, 0) as total_pass_revenue
    , ROUND(art.total_art_revenue
            + COALESCE(pt.pipe_primary, 0) + COALESCE(pst.pipe_secondary, 0)
            + COALESCE(pass.pass_primary, 0) + COALESCE(passs.pass_secondary, 0)
            + COALESCE(ct.collab_revenue, 0), 4) as grand_total_revenue
    , art.total_art_volume
    , art.artworks_sold_primary as artworks_sold
    , COALESCE(pt.pipe_primary_qty, 0) + COALESCE(ct.collab_quantity, 0) as non_one_of_one_sold
    -- Per-period breakdowns
    , art.genesis_revenue, art.fragmentation_revenue, art.paradox_revenue
    , art.rebellion_revenue, art.absurdism_revenue, art.interstice_revenue
    , art.temporal_echoes_revenue, art.morphogenesis_revenue, art.synthetic_histories_revenue
    , art.cosmic_garden_revenue, art.liminal_thresholds_revenue, art.semantic_drift_revenue
    , art.attention_economy_revenue, art.collapse_aesthetics_revenue
    -- Breakdown components
    , COALESCE(pt.pipe_primary, 0) as pipe_primary_revenue
    , COALESCE(pst.pipe_secondary, 0) as pipe_secondary_revenue
    , COALESCE(pass.pass_primary, 0) as pass_primary_revenue
    , COALESCE(passs.pass_secondary, 0) as pass_secondary_revenue
FROM art_totals art
CROSS JOIN pipe_totals pt
CROSS JOIN pipe_sec_totals pst
CROSS JOIN pass_totals pass
CROSS JOIN pass_sec_totals passs
CROSS JOIN collab_totals ct
