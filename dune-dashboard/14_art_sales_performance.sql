-- ============================================================
-- BOTTO DASHBOARD: Art Sales Performance by Period
-- ============================================================
-- Charts:
--   1. Table: per-period performance stats
--   2. Bar: total_revenue per period (sorted by sort_order)
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
        AND eth.contract_address = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
        AND botto.minute >= (SELECT start_date + INTERVAL '7' DAY FROM dates)
        AND botto.minute <= (SELECT end_date FROM dates)
        AND day_of_week(botto.minute) = 2
        AND hour(botto.minute) = 22
        AND minute(botto.minute) = 0
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

, all_art_sales AS (
    -- ===== SUPERRARE PERIODS =====

    -- Genesis
    SELECT block_time, amount_original as sales,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END as revenue,
        1 as quantity,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN 'primary' ELSE 'secondary' END as sale_type,
        'Genesis' as period
    FROM superrare_sales
    WHERE nft_contract_address = 0xb932a70a57673d89f4acffbe830e8ed7f75fb9e0
      AND cast(token_id as varchar) IN (
          '29715','29922','30114','30298','30443','30639','30887','31057','31200','31352','31447',
          '31546','31704','31887','32068','32242','32457','32619','32737','33018','33163','33332',
          '33501','33637','33754','33879','34066','34231','34399','34540','34684','34910','35069',
          '35208','35353','35482','35616','35769','35934','36127','36315','36525','36702','36905',
          '37149','37380','37657','37877','38050','38335','38615','38913')
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)

    UNION ALL
    -- Fragmentation
    SELECT block_time, amount_original,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        1,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN 'primary' ELSE 'secondary' END,
        'Fragmentation'
    FROM superrare_sales
    WHERE nft_contract_address = 0xa4dc93da01458d38f691db5c98e9157891febe86
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)

    UNION ALL
    -- Paradox
    SELECT block_time, amount_original,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        1,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN 'primary' ELSE 'secondary' END,
        'Paradox'
    FROM superrare_sales
    WHERE nft_contract_address = 0xbdf4f17b7d638d7d3e5dcadf27e812b07b2b5c9e
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)

    UNION ALL
    -- ===== NFT.TRADES PERIODS (own contracts) =====

    -- Rebellion
    SELECT block_time, amount_original,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        cast(number_of_items as integer),
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN 'primary' ELSE 'secondary' END,
        'Rebellion'
    FROM nft.trades
    WHERE nft_contract_address = 0x1c7576619032eaf8b8a938c352e535bba92a366c
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)

    UNION ALL
    -- Absurdism
    SELECT block_time, amount_original,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        cast(number_of_items as integer),
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN 'primary' ELSE 'secondary' END,
        'Absurdism'
    FROM nft.trades
    WHERE nft_contract_address = 0x47542736c9d1086dc87cc45138b2d57ec79eafa3
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)

    UNION ALL
    -- ===== 2024 CONTRACT (4 periods by token_id range) =====
    SELECT block_time, amount_original,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        cast(number_of_items as integer),
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN 'primary' ELSE 'secondary' END,
        CASE
            WHEN token_id >= 1 AND token_id <= 13 THEN 'Interstice'
            WHEN token_id > 13 AND token_id <= 26 THEN 'Temporal Echoes'
            WHEN token_id > 26 AND token_id <= 39 THEN 'Morphogenesis'
            WHEN token_id > 39 AND token_id <= 52 THEN 'Synthetic Histories'
        END
    FROM nft.trades
    WHERE nft_contract_address = 0xca53bb6cdfcd5bf437bf4ac6d17c3b0e67d8a83e
      AND token_id >= 1 AND token_id <= 52
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)

    UNION ALL
    -- ===== 2025 CONTRACT (4 periods by token_id range) =====
    SELECT block_time, amount_original,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        cast(number_of_items as integer),
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN 'primary' ELSE 'secondary' END,
        CASE
            WHEN token_id >= 1 AND token_id <= 13 THEN 'Cosmic Garden'
            WHEN token_id > 13 AND token_id <= 26 THEN 'Liminal Thresholds'
            WHEN token_id > 26 AND token_id <= 39 THEN 'Semantic Drift'
            WHEN token_id > 39 AND token_id <= 52 THEN 'Attention Economy'
        END
    FROM nft.trades
    WHERE nft_contract_address = 0x66cd3ede22a25eef3cc8799381b99b1d4f0983f8
      AND token_id >= 1 AND token_id <= 52
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)

    UNION ALL
    -- ===== 2026 CONTRACT =====
    SELECT block_time, amount_original,
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN amount_original * 0.85 ELSE amount_original / 10 END,
        cast(number_of_items as integer),
        CASE WHEN seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
             THEN 'primary' ELSE 'secondary' END,
        'Collapse Aesthetics'
    FROM nft.trades
    WHERE nft_contract_address = 0x3cb787d48c34cca29653f54efc9112b4134b879d
      AND token_id >= 1 AND token_id <= 13
      AND block_time >= (SELECT start_date FROM dates) AND block_time < (SELECT end_date FROM dates)
)

, period_order AS (
    SELECT * FROM (VALUES
        ('Genesis', 1),
        ('Fragmentation', 2),
        ('Paradox', 3),
        ('Rebellion', 4),
        ('Absurdism', 5),
        ('Interstice', 6),
        ('Temporal Echoes', 7),
        ('Morphogenesis', 8),
        ('Synthetic Histories', 9),
        ('Cosmic Garden', 10),
        ('Liminal Thresholds', 11),
        ('Semantic Drift', 12),
        ('Attention Economy', 13),
        ('Collapse Aesthetics', 14)
    ) AS t(period, sort_order)
)

, period_stats AS (
    SELECT
          a.period
        , COUNT(*) as total_sales
        , SUM(CASE WHEN a.sale_type = 'primary' THEN a.quantity ELSE 0 END) as primary_count
        , SUM(CASE WHEN a.sale_type = 'secondary' THEN a.quantity ELSE 0 END) as secondary_count
        , ROUND(SUM(a.revenue), 4) as total_revenue
        , ROUND(SUM(CASE WHEN a.sale_type = 'primary' THEN a.revenue ELSE 0 END), 4) as primary_revenue
        , ROUND(SUM(CASE WHEN a.sale_type = 'secondary' THEN a.revenue ELSE 0 END), 4) as secondary_revenue
        , ROUND(AVG(a.sales), 4) as avg_price
        , ROUND(MIN(a.sales), 4) as min_price
        , ROUND(MAX(a.sales), 4) as max_price
        , ROUND(SUM(CASE WHEN a.sale_type = 'primary' THEN a.revenue ELSE 0 END)
                / NULLIF(SUM(a.revenue), 0) * 100, 1) as primary_pct
    FROM all_art_sales a
    WHERE a.period IS NOT NULL
    GROUP BY a.period
)

SELECT
      ps.period
    , po.sort_order
    , ps.total_sales
    , ps.primary_count
    , ps.secondary_count
    , ps.total_revenue
    , ps.primary_revenue
    , ps.secondary_revenue
    , ps.avg_price
    , ps.min_price
    , ps.max_price
    , ps.primary_pct
    , ROUND(ps.total_revenue - LAG(ps.total_revenue) OVER (ORDER BY po.sort_order), 4) as revenue_change
    , ROUND((ps.total_revenue - LAG(ps.total_revenue) OVER (ORDER BY po.sort_order))
            / NULLIF(LAG(ps.total_revenue) OVER (ORDER BY po.sort_order), 0) * 100, 1) as revenue_change_pct
FROM period_stats ps
JOIN period_order po ON po.period = ps.period
ORDER BY po.sort_order ASC
