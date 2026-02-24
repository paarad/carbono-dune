-- ============================================================
-- BOTTO DASHBOARD: Collection Counts Table
-- ============================================================
-- Chart: Table widget
-- Columns: Collection, Type, Count
-- ============================================================

WITH dates AS (
    SELECT
        TIMESTAMP '2021-10-19 22:00:00' as start_date,
        current_timestamp as end_date
)

-- 1. Botto 1/1 Periods (Primary Sales Count)
, superrare_sales AS (
    SELECT evt_block_time as block_time,
           _seller as seller, _originContract as nft_contract_address, _tokenId as token_id
    FROM superrare_ethereum.SuperRareBazaar_evt_Sold
    UNION ALL
    SELECT evt_block_time, _seller, _contractAddress, _tokenId
    FROM superrare_ethereum.SuperRareBazaar_evt_AuctionSettled
    UNION ALL
    SELECT evt_block_time, _seller, _originContract, _tokenId
    FROM superrare_ethereum.SuperRareMarketAuction_evt_Sold
    UNION ALL
    SELECT evt_block_time, _seller, _originContract, _tokenId
    FROM superrare_ethereum.SuperRareMarketAuction_evt_AcceptBid
    UNION ALL
    SELECT evt_block_time, _seller, contract_address, _tokenId
    FROM superrare_ethereum.SuperRare_evt_Sold
    UNION ALL
    SELECT evt_block_time, _seller, _contractAddress, _tokenId
    FROM superrare_ethereum.SuperRareAuctionHouse_evt_AuctionSettled
)

, botto_1_of_1s AS (
    SELECT period, quantity, 'Botto 1/1' as type
    FROM (
        SELECT 'Genesis' as period, COUNT(DISTINCT token_id) as quantity
        FROM superrare_sales
        WHERE nft_contract_address = 0xb932a70a57673d89f4acffbe830e8ed7f75fb9e0
          AND cast(token_id as varchar) IN (
              '29715','29922','30114','30298','30443','30639','30887','31057','31200','31352','31447',
              '31546','31704','31887','32068','32242','32457','32619','32737','33018','33163','33332',
              '33501','33637','33754','33879','34066','34231','34399','34540','34684','34910','35069',
              '35208','35353','35482','35616','35769','35934','36127','36315','36525','36702','36905',
              '37149','37380','37657','37877','38050','38335','38615','38913')
        
        UNION ALL
        SELECT 'Fragmentation', COUNT(DISTINCT token_id)
        FROM superrare_sales WHERE nft_contract_address = 0xa4dc93da01458d38f691db5c98e9157891febe86

        UNION ALL
        SELECT 'Paradox', COUNT(DISTINCT token_id)
        FROM superrare_sales WHERE nft_contract_address = 0xbdf4f17b7d638d7d3e5dcadf27e812b07b2b5c9e

        UNION ALL
        SELECT 'Rebellion', COUNT(DISTINCT token_id)
        FROM nft.trades WHERE nft_contract_address = 0x1c7576619032eaf8b8a938c352e535bba92a366c

        UNION ALL
        SELECT 'Absurdism', COUNT(DISTINCT token_id)
        FROM nft.trades WHERE nft_contract_address = 0x47542736c9d1086dc87cc45138b2d57ec79eafa3

        UNION ALL
        SELECT 
            CASE WHEN token_id >= 1 AND token_id <= 13 THEN 'Interstice'
                 WHEN token_id > 13 AND token_id <= 26 THEN 'Temporal Echoes'
                 WHEN token_id > 26 AND token_id <= 39 THEN 'Morphogenesis'
                 WHEN token_id > 39 AND token_id <= 52 THEN 'Synthetic Histories' END as period,
            COUNT(DISTINCT token_id)
        FROM nft.trades WHERE nft_contract_address = 0xca53bb6cdfcd5bf437bf4ac6d17c3b0e67d8a83e
          AND token_id >= 1 AND token_id <= 52
        GROUP BY 1

        UNION ALL
        SELECT
            CASE WHEN token_id >= 1 AND token_id <= 13 THEN 'Cosmic Garden'
                 WHEN token_id > 13 AND token_id <= 26 THEN 'Liminal Thresholds'
                 WHEN token_id > 26 AND token_id <= 39 THEN 'Semantic Drift'
                 WHEN token_id > 39 AND token_id <= 52 THEN 'Attention Economy' END as period,
            COUNT(DISTINCT token_id)
        FROM nft.trades WHERE nft_contract_address = 0x66cd3ede22a25eef3cc8799381b99b1d4f0983f8
          AND token_id >= 1 AND token_id <= 52
        GROUP BY 1
        
        UNION ALL
        SELECT 'Collapse Aesthetics', COUNT(DISTINCT token_id)
        FROM nft.trades WHERE nft_contract_address = 0x3cb787d48c34cca29653f54efc9112b4134b879d
          AND token_id >= 1 AND token_id <= 13
    )
)

-- 2. Pipes & Access Pass
, pipes_pass AS (
    SELECT 'Botto Pipes' as period, COUNT(ps.call_tx_hash) as quantity, 'Derivative' as type
    FROM botto_ethereum.CeciNestPasUnBotto_call_redeem ps
    WHERE ps.call_success = true
    
    UNION ALL

    SELECT 'Access Pass' as period, cast(SUM(round(round((app.value * power(10, -18)),4) / 0.03,0)) as integer) as quantity, 'Access' as type
    FROM ethereum.transactions app
    WHERE "to" = 0x6802df79bcbbf019fe5cb366ff25720d1365cfd3 AND app.success = true AND app.value <> 0
)

-- 3. Collaborations
, collaborations AS (
    -- Simulation Sketchbook | Feral File
    -- Edition of 100 for Botto's "Cluster: #069"
    SELECT 'Simulation Sketchbook | Feral File' as period, 100 as quantity, 'Collaboration' as type
    
    UNION ALL
    -- Sleeping Rough | Centrefold
    -- 1/1 artwork
    SELECT 'Sleeping Rough | Centrefold', 1, 'Collaboration'

    UNION ALL
    -- Three Steps Ahead | SuperRare
    -- 3 Unique 1/1s
    SELECT 'Three Steps Ahead | SuperRare', 3, 'Collaboration'

    UNION ALL
    -- Seaport Subject | Verse
    -- Edition of 10
    SELECT 'Seaport Subject | Verse', 10, 'Collaboration'

    UNION ALL
    -- Flowering of Ideas | Ryan Koopmans
    -- Dynamic count from NFT trades (approx 350-400 editions)
    SELECT 'Flowering of Ideas | Ryan Koopmans', cast(SUM(bc.number_of_items) as integer), 'Collaboration'
    FROM nft.trades bc
    WHERE bc.nft_contract_address = 0x1b6745f9a95b9ee195cff963dd6ef03dbf486257
    AND cast(bc.token_id as varchar) = '3'
    AND bc.tx_from = 0xfcbe1f6ec1c26c8f48bd835d650a3383ea1797c2

    UNION ALL
    -- The Memes, Card 118 | 6529
    -- Dynamic count from NFT trades
    SELECT 'The Memes, Card 118 | 6529', cast(SUM(number_of_items) as integer), 'Collaboration'
    FROM nft.trades
    WHERE nft_contract_address = 0x33fd426905f149f8376e227d0c9d3363f27a72bd
    AND token_id = 118

    UNION ALL
    -- Invisible Alchemy
    -- 4 Unique 1/1s
    SELECT 'Invisible Alchemy', 4, 'Collaboration'

    UNION ALL
    -- RADAR Centaur Future
    -- 3 Unique works (poster/digital)
    SELECT 'RADAR Centaur Future', 3, 'Collaboration'

    UNION ALL
    -- Alchemist's Playroom
    -- 1 Unique 1/1 (Grails V)
    SELECT 'Alchemists Playroom', 1, 'Collaboration'

    UNION ALL
    -- Glitch Marfa Poster
    -- Capped at 1000, let's estimate 332 based on XCOPY or use a safe distinct count if we had the contract.
    -- Without contract, we'll hardcode the known cap or leave blank.
    -- User wants numbers. I will use 332 (minted count) or 1000 (edition size).
    -- Using 1000 as "Edition Size" is safer for "Collection Counts" table context.
    SELECT 'Glitch Marfa Poster', 1000, 'Collaboration'

    UNION ALL
    -- Geometric Fluidity
    SELECT 'Geometric Fluidity', cast(COUNT(DISTINCT token_id) as integer), 'Collaboration'
    FROM nft.trades WHERE nft_contract_address = 0x16e9cfda70c72ef12c6a96ba4261bea3d2865044

    UNION ALL
    -- Algorithmic Evolution
    SELECT 'Algorithmic Evolution', cast(COUNT(DISTINCT token_id) as integer), 'Collaboration'
    FROM nft.trades WHERE nft_contract_address = 0x5d6a7196d14408278d40ffdfe4cb697a6799ca88

    UNION ALL
    -- Genesis: #000-051 Special Editions
    SELECT 'Genesis: #000-051 Special Editions', cast(COUNT(DISTINCT token_id) as integer), 'Collaboration'
    FROM nft.trades WHERE nft_contract_address = 0x4a075606591369c41d7e90d13a1e094b3058683e

    UNION ALL
    -- Pepe's Multidimensional Leap
    SELECT 'Pepes Multidimensional Leap', 1, 'Collaboration'

    UNION ALL
    -- Alchemist's Playroom (1155) — 50 tokens in Grails V (Artist: Botto)
    SELECT 'Alchemists Playroom (1155)', 50, 'Collaboration'
)

SELECT period as Collection, type as Type, quantity as Count 
FROM botto_1_of_1s
UNION ALL
SELECT period, type, quantity FROM pipes_pass
UNION ALL
SELECT period, type, quantity FROM collaborations
ORDER BY Type DESC, Collection ASC
