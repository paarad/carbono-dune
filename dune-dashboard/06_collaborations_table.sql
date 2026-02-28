-- ============================================================
-- BOTTO DASHBOARD: Collaborations Table
-- ============================================================
-- Chart: Table widget
-- Shows individual collaboration events with date and revenue
-- ============================================================
-- NOTE: Add new collaborations at the bottom with UNION SELECT
-- ============================================================

WITH eth_prices AS (
    SELECT
        date_trunc('week', p.minute - INTERVAL '1' day) + INTERVAL '1' day as week,
        MAX(p.price) as eth_price
    FROM prices.usd p
    WHERE p.contract_address = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
    AND p.minute BETWEEN DATE '2021-10-19' AND current_timestamp
    GROUP BY date_trunc('week', p.minute - INTERVAL '1' day) + INTERVAL '1' day
)

SELECT * FROM (

    -- Simulation Sketchbook | Feral File
    SELECT
          DATE '2022-10-24' as mint_date
        , 'Simulation Sketchbook | Feral File' as collection
        , 'https://www.vellumla.com/news/vellum-la-x-feral-file-present-simulation-sketchbook-works-in-process' as link
        , cast(NULL as double) as revenue_eth

    UNION ALL
    -- Sleeping Rough | Centrefold
    SELECT DATE '2023-03-02', 'Sleeping Rough | Centrefold',
        'https://verse.works/artworks/27c885d5-4b98-43ed-bf03-ec42996ac891', NULL

    UNION ALL
    -- Three Steps Ahead | SuperRare
    SELECT DATE '2023-03-20', 'Three Steps Ahead | SuperRare',
        'https://rarepass.superrare.com/series',
        bc.value / 1e+18
    FROM ethereum.traces bc
    WHERE bc.tx_hash = 0x13c973087e5d0577b7edee854364285eaee949c3f8bcc8fd500f79e9f9844fea
    AND bc.block_number = 16887424
    AND bc.to = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49

    UNION ALL
    -- Seaport Subject | Verse
    SELECT DATE '2023-03-27', 'Seaport Subject | Verse',
        'https://verse.works/artworks/5227e19b-c6aa-4d00-b6a9-dff08f8cc1be',
        SUM(royalty_fee_amount)
    FROM seaport_ethereum.trades
    WHERE nft_contract_address = 0xdcb1c3275ca97f148f6da1b0ee85bcb75cc9c5a4

    UNION ALL
    -- Flowering of Ideas | Ryan Koopmans
    SELECT DATE '2023-05-24', 'Flowering of Ideas | Ryan Koopmans',
        'https://superrare.com/0x1b6745f9a95b9ee195cff963dd6ef03dbf486257/flowering-of-ideas-w--botto-3',
        bc.amount_original * 0.85 / 2
    FROM nft.trades bc
    WHERE bc.nft_contract_address = 0x1b6745f9a95b9ee195cff963dd6ef03dbf486257
    AND cast(bc.token_id as varchar) = '3'
    AND bc.tx_from = 0xfcbe1f6ec1c26c8f48bd835d650a3383ea1797c2

    UNION ALL
    -- The Memes, Card 118 | 6529
    -- NFT contract: 0x33FD426905F149f8376e227d0C9D3340AaD17aF1
    -- TODO: Revenue from direct ETH transfers — need specific txs
    SELECT DATE '2023-06-20', 'The Memes, Card 118 | 6529',
        'https://seize.io/the-memes/118',
        cast(NULL as double)

    UNION ALL
    -- Invisible Alchemy: Communion of Harvested Worlds
    SELECT DATE '2023-12-10', 'Invisible Alchemy: Communion of Harvested Worlds',
        'https://makersplace.com/product/invisible-alchemy-1-of-1-494267/',
        value * POWER(10, -18)
    FROM transfers_ethereum.eth
    WHERE "from" = 0xbA73cf4a0479d2AdbeF107E16bC23a964679129B
    AND "to" = 0x000a837Ddd815Bcba0fa91a98a50AA7A3fA62C9C

    UNION ALL
    -- RADAR Centaur Future
    SELECT DATE '2023-12-11', 'RADAR Centaur Future', '',
        value / 1e+18
    FROM ethereum.traces
    WHERE tx_hash = 0x83a3de49bf7e2188e3f71b4a699e0db45b1dea92b53731d79c485cc2d0c86ea4
    AND block_number = 19059527
    AND "to" = 0x35bb964878d7B6ddFA69cF0b97EE63fa3C9d9b49

    UNION ALL
    -- Alchemist's Playroom
    SELECT DATE '2023-12-15', 'Alchemists Playroom',
        'https://www.proof.xyz/grails/season-5/the-alchemists-playroom',
        (SELECT value / 1e+18 FROM ethereum.traces
         WHERE tx_hash = 0x74430951f1b1ec0c438e8b51fd57e9298fd17cf6c1be0f6657a34fa736e4d2c7
         AND block_number = 18836143
         AND "to" = 0x35bb964878d7B6ddFA69cF0b97EE63fa3C9d9b49)
        +
        (SELECT SUM(value * POWER(10, -18)) FROM transfers_ethereum.eth
         WHERE ("from" = 0x431E0Ae9e2c40f60A6773AFBe4A1659A9c078d11 OR "from" = 0xb81FbcBD325473bFc6f28643C8dd0fb0bdA5F3B2)
         AND "to" = 0x35bb964878d7B6ddFA69cF0b97EE63fa3C9d9b49
         AND tx_hash <> 0x74430951f1b1ec0c438e8b51fd57e9298fd17cf6c1be0f6657a34fa736e4d2c7)

    UNION ALL
    -- Invisible Alchemy: Temporal Echoes
    SELECT DATE '2024-04-01', 'Invisible Alchemy: Temporal Echoes',
        'https://makersplace.com/product/invisible-alchemy-temporal-echoes-1-of-1-497418/',
        value_decimal
    FROM transfers_ethereum.eth
    WHERE tx_hash = 0x1bbc69a37a9460b86c0388f678e7b87e53619df88eccbc27dffb7a462e70d1de
    AND "to" = 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c

    UNION ALL
    -- Glitch Marfa Poster
    SELECT CAST(et.evt_block_time AS DATE), 'Glitch Marfa Poster', '',
        SUM(value * POWER(10, -6)) / COALESCE(ep.eth_price, 1)
    FROM erc20_ethereum.evt_transfer et
    JOIN eth_prices ep
        ON DATE_TRUNC('week', CAST(et.evt_block_time AS TIMESTAMP) - INTERVAL '1' day) + INTERVAL '1' day = ep.week
    WHERE et."from" = 0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE
      AND et."to" = 0x35bb964878d7B6ddFA69cF0b97EE63fa3C9d9b49
      AND et.contract_address = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    GROUP BY CAST(et.evt_block_time AS DATE), ep.eth_price

    UNION ALL
    -- Geometric Fluidity
    SELECT MIN(CAST(bc.block_time AS DATE)), 'Geometric Fluidity', '',
        SUM(CASE WHEN bc.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
            THEN bc.royalty_fee_amount ELSE 0 END)
    FROM nft.trades bc
    WHERE bc.nft_contract_address = 0x16e9cfda70c72ef12c6a96ba4261bea3d2865044

    UNION ALL
    -- Algorithmic Evolution
    SELECT MIN(CAST(bc.block_time AS DATE)), 'Algorithmic Evolution', '',
        SUM(CASE WHEN bc.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
            THEN bc.royalty_fee_amount ELSE 0 END)
    FROM nft.trades bc
    WHERE bc.nft_contract_address = 0x5d6a7196d14408278d40ffdfe4cb697a6799ca88

    UNION ALL
    -- Genesis: #000-051 Special Editions
    SELECT MIN(CAST(bc.block_time AS DATE)), 'Genesis: #000-051 Special Editions', '',
        SUM(CASE WHEN bc.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
            THEN bc.royalty_fee_amount ELSE 0 END)
    FROM nft.trades bc
    WHERE bc.nft_contract_address = 0x4a075606591369c41d7e90d13a1e094b3058683e

    UNION ALL
    -- Pepe's Multidimensional Leap
    SELECT MIN(CAST(bc.block_time AS DATE)), 'Pepes Multidimensional Leap', '',
        SUM(CASE WHEN bc.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
            THEN bc.royalty_fee_amount ELSE 0 END)
    FROM nft.trades bc
    WHERE bc.nft_contract_address = 0xe70659b717112ac4e14284d0db2f5d5703df8e43
      AND bc.token_id = 306

    UNION ALL
    -- Alchemist's Playroom (1155) — 50 tokens in Grails V (Artist: Botto)
    SELECT MIN(CAST(bc.block_time AS DATE)), 'Alchemists Playroom (1155)', '',
        SUM(CASE WHEN bc.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
            THEN bc.royalty_fee_amount ELSE 0 END)
    FROM nft.trades bc
    WHERE bc.nft_contract_address = 0x92a50fe6ede411bd26e171b97472e24d245349b8
      AND bc.token_id IN (3,21,49,61,76,78,83,93,216,238,255,258,266,269,273,278,279,286,293,
          304,314,327,328,334,343,351,360,373,376,379,385,390,393,394,395,397,
          400,401,404,407,409,411,412,413,416,417,418,419,420,421)

) collabs
ORDER BY mint_date ASC
