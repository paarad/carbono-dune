WITH dates AS (
    SELECT
        TIMESTAMP '2021-10-19 22:00:00' as start_date,
        current_timestamp as end_date
)

, prices AS (
    SELECT
          date_trunc('hour', eth.minute) as week_end
        , date_trunc('hour', eth.minute - INTERVAL '7' DAY) as week_start
        , concat(cast(row_number() OVER (ORDER BY eth.minute ASC) as varchar),
            ' (',date_format(date_trunc('hour', eth.minute - INTERVAL '7' DAY),'%Y-%m-%d %H:%i'),
            ' to ',date_format(date_trunc('hour', eth.minute),'%Y-%m-%d %H:%i'),')') as week
        , (row_number() OVER (ORDER BY eth.minute ASC)) as week_number
        , concat(date_format(date_trunc('hour', eth.minute - INTERVAL '7' DAY),'%Y-%m-%d %H:%i'),
            ' to ',date_format(date_trunc('hour', eth.minute),'%Y-%m-%d %H:%i')) as week_period
        , botto.price as botto_price
        , eth.price / botto.price as eth_to_botto
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
    ORDER BY week_end DESC
)

, superrare_sales AS (
    -- SuperRare Bazaar Sold
    SELECT
        evt_block_time as block_time,
        cast(_amount as double) / 1e18 as amount_original,
        _seller as seller,
        _buyer as buyer,
        _originContract as nft_contract_address, -- Use _originContract for Bazaar Sold
        _tokenId as token_id,
        cast(NULL as double) as royalty_fee_percentage -- Default or joined
    FROM superrare_ethereum.SuperRareBazaar_evt_Sold
    UNION ALL
    -- SuperRare Bazaar AuctionSettled
    SELECT
        evt_block_time as block_time,
        cast(_amount as double) / 1e18 as amount_original,
        _seller as seller,
        _bidder as buyer, -- Assuming _bidder for AuctionSettled
        _contractAddress as nft_contract_address, -- Check field name for Bazaar AuctionSettled. Usually _contractAddress or _originContract
        _tokenId as token_id,
        cast(NULL as double) as royalty_fee_percentage
    FROM superrare_ethereum.SuperRareBazaar_evt_AuctionSettled
    UNION ALL
    -- SuperRare MarketAuction Sold
    SELECT
        evt_block_time as block_time,
        cast(_amount as double) / 1e18 as amount_original,
        _seller as seller,
        _buyer as buyer,
        _originContract as nft_contract_address,
        _tokenId as token_id,
        cast(NULL as double) as royalty_fee_percentage
    FROM superrare_ethereum.SuperRareMarketAuction_evt_Sold
    UNION ALL
    -- SuperRare MarketAuction AcceptBid
    SELECT
        evt_block_time as block_time,
        cast(_amount as double) / 1e18 as amount_original,
        _seller as seller,
        _bidder as buyer,
        _originContract as nft_contract_address,
        _tokenId as token_id,
        cast(NULL as double) as royalty_fee_percentage
    FROM superrare_ethereum.SuperRareMarketAuction_evt_AcceptBid
    UNION ALL
    -- SuperRare (Legacy Marketplace) Sold
    SELECT
        evt_block_time as block_time,
        cast(_amount as double) / 1e18 as amount_original,
        _seller as seller,
        _buyer as buyer,
        contract_address as nft_contract_address, -- Use contract_address for legacy (it handles its own tokens)
        _tokenId as token_id,
        cast(NULL as double) as royalty_fee_percentage
    FROM superrare_ethereum.SuperRare_evt_Sold
    UNION ALL
    -- SuperRare AuctionHouse AuctionSettled
    SELECT
        evt_block_time as block_time,
        cast(_amount as double) / 1e18 as amount_original,
        _seller as seller,
        _bidder as buyer,
        _contractAddress as nft_contract_address,
        _tokenId as token_id,
        cast(NULL as double) as royalty_fee_percentage
    FROM superrare_ethereum.SuperRareAuctionHouse_evt_AuctionSettled
)

, all_botto_trades AS (
    -- SuperRare Sales (Genesis, Fragmentation, Paradox)
    SELECT
        block_time,
        amount_original,
        seller,
        nft_contract_address,
        cast(token_id as varchar) as token_id_str,
        1 as quantity,
        'superrare' as source
    FROM superrare_sales
    
    UNION ALL
    
    -- NFT Trades (Rebellion, Absurdism, 2024, 2025, 2026)
    SELECT
        block_time,
        amount_original,
        seller,
        nft_contract_address,
        cast(token_id as varchar) as token_id_str,
        cast(cast(number_of_items as double) as integer) as quantity,
        'nft_trades' as source
    FROM nft.trades
    WHERE nft_contract_address IN (
        0x1c7576619032eaf8b8a938c352e535bba92a366c, -- Rebellion
        0x47542736c9d1086dc87cc45138b2d57ec79eafa3, -- Absurdism
        0xca53bb6cdfcd5bf437bf4ac6d17c3b0e67d8a83e, -- 2024 Contract
        0x66cd3ede22a25eef3cc8799381b99b1d4f0983f8, -- 2025 Contract
        0x3cb787d48c34cca29653f54efc9112b4134b879d  -- 2026 Contract
    )
)

, botto_sales_classified AS (
    SELECT
        t.*,
        -- Classify Sale Type
        CASE
            WHEN t.seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656) 
            THEN 'primary'
            ELSE 'secondary'
        END as sale_type,
        -- Calculate Revenue
        CASE
            WHEN t.seller IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c, 0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656) 
            THEN t.amount_original * 0.85
            ELSE t.amount_original / 10 -- Standard logic from original query for secondary revenue
        END as revenue,
        -- Classify Period
        CASE
            WHEN t.nft_contract_address = 0xb932a70a57673d89f4acffbe830e8ed7f75fb9e0 AND t.token_id_str IN ('29715', '29922', '30114', '30298', '30443', '30639', '30887', '31057', '31200', '31352', '31447', '31546', '31704', '31887', '32068', '32242', '32457', '32619', '32737', '33018', '33163', '33332', '33501', '33637', '33754', '33879', '34066', '34231', '34399', '34540', '34684', '34910', '35069', '35208', '35353', '35482', '35616', '35769', '35934', '36127', '36315', '36525', '36702', '36905', '37149', '37380', '37657', '37877', '38050', '38335', '38615', '38913') THEN 'genesis'
            WHEN t.nft_contract_address = 0xa4dc93da01458d38f691db5c98e9157891febe86 THEN 'fragmentation'
            WHEN t.nft_contract_address = 0xbdf4f17b7d638d7d3e5dcadf27e812b07b2b5c9e THEN 'paradox'
            WHEN t.nft_contract_address = 0x1c7576619032eaf8b8a938c352e535bba92a366c THEN 'rebellion'
            WHEN t.nft_contract_address = 0x47542736c9d1086dc87cc45138b2d57ec79eafa3 THEN 'absurdism'
            -- 2024 Contract Periods
            WHEN t.nft_contract_address = 0xca53bb6cdfcd5bf437bf4ac6d17c3b0e67d8a83e AND TRY_CAST(t.token_id_str as double) BETWEEN 1 AND 13 THEN 'interstice'
            WHEN t.nft_contract_address = 0xca53bb6cdfcd5bf437bf4ac6d17c3b0e67d8a83e AND TRY_CAST(t.token_id_str as double) BETWEEN 14 AND 26 THEN 'temporal_echoes'
            WHEN t.nft_contract_address = 0xca53bb6cdfcd5bf437bf4ac6d17c3b0e67d8a83e AND TRY_CAST(t.token_id_str as double) BETWEEN 27 AND 39 THEN 'morphogenesis'
            WHEN t.nft_contract_address = 0xca53bb6cdfcd5bf437bf4ac6d17c3b0e67d8a83e AND TRY_CAST(t.token_id_str as double) BETWEEN 40 AND 52 THEN 'synthetic_histories'
            -- 2025 Contract Periods
            WHEN t.nft_contract_address = 0x66cd3ede22a25eef3cc8799381b99b1d4f0983f8 AND TRY_CAST(t.token_id_str as double) BETWEEN 1 AND 13 THEN 'cosmic_garden'
            WHEN t.nft_contract_address = 0x66cd3ede22a25eef3cc8799381b99b1d4f0983f8 AND TRY_CAST(t.token_id_str as double) BETWEEN 14 AND 26 THEN 'liminal_thresholds'
            WHEN t.nft_contract_address = 0x66cd3ede22a25eef3cc8799381b99b1d4f0983f8 AND TRY_CAST(t.token_id_str as double) BETWEEN 27 AND 39 THEN 'semantic_drift'
            WHEN t.nft_contract_address = 0x66cd3ede22a25eef3cc8799381b99b1d4f0983f8 AND TRY_CAST(t.token_id_str as double) BETWEEN 40 AND 52 THEN 'attention_economy'
            -- 2026 Contract Periods
            WHEN t.nft_contract_address = 0x3cb787d48c34cca29653f54efc9112b4134b879d AND TRY_CAST(t.token_id_str as double) BETWEEN 1 AND 13 THEN 'collapse_aesthetics'
            ELSE 'other'
        END as period
    FROM all_botto_trades t
)

-- Access Pass and Pipes remain as separate or can be kept, they are small.
-- Collaborations also distinct.

, collaborations AS (
    SELECT
          p.week_end
        , bc.value / 1e+18 as sales
        , bc.value / 1e+18 as revenue
        , cast(1 as integer) as quantity
    FROM ethereum.traces bc
    JOIN prices p
        ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates)
    AND   bc.block_time < (SELECT end_date FROM dates)
    -- Rarepass share revenue:
    AND bc.tx_hash = 0x13c973087e5d0577b7edee854364285eaee949c3f8bcc8fd500f79e9f9844fea
    AND bc.block_number = 16887424
    AND bc.to = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    UNION SELECT
          p.week_end
        , bc.amount_original as sales
        , bc.royalty_fee_amount as revenue
        , cast(1 as integer) as quantity
    FROM seaport_ethereum.trades bc
    JOIN prices p
        ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates)
    AND   bc.block_time < (SELECT end_date FROM dates)
    AND bc.nft_contract_address = 0xdcb1c3275ca97f148f6da1b0ee85bcb75cc9c5a4
    UNION SELECT
          p.week_end
        , SUM(bc.amount_original) as sales
        , SUM(bc.amount_original * 0.85 / 2) as revenue
        , cast(SUM(bc.number_of_items) as integer) as quantity
    FROM nft.trades bc
    JOIN prices p
        ON bc.block_time >= p.week_start AND bc.block_time < p.week_end
    WHERE bc.block_time >= (SELECT start_date FROM dates)
    AND   bc.block_time < (SELECT end_date FROM dates)
    --Filtering to only Botto x Ryan Koopmans collaboration:
    AND bc.nft_contract_address = 0x1b6745f9a95b9ee195cff963dd6ef03dbf486257
    AND cast(bc.token_id as varchar) = '3'
    AND bc.tx_from = 0xfcbe1f6ec1c26c8f48bd835d650a3383ea1797c2
    GROUP BY p.week_end
    ORDER BY 1 DESC
)

, pipe_primary AS (
    SELECT
          p.week_end
        , SUM(cast(json_extract_scalar(ps.permit_, '$.minimumPrice') as double) * power(10, -18)) as revenue
        , COUNT(ps.call_tx_hash) as quantity
    FROM botto_ethereum.CeciNestPasUnBotto_call_redeem ps
    JOIN prices p
        ON ps.call_block_time >= p.week_start AND ps.call_block_time < p.week_end
    WHERE ps.call_block_time >= (SELECT start_date FROM dates)
    AND   ps.call_block_time < (SELECT end_date FROM dates)
    AND ps.call_success = true
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, pipe_secondary AS (
    SELECT
          p.week_end
        , SUM(pr.amount_original) as sales
        , SUM(pr.royalty_fee_amount) as revenue
        , SUM(pr.number_of_items) as quantity
    FROM nft.trades pr
    JOIN prices p
        ON pr.block_time >= p.week_start AND pr.block_time < p.week_end
    WHERE pr.block_time >= (SELECT start_date FROM dates)
    AND   pr.block_time < (SELECT end_date FROM dates)
    -- Filter for "Ceci n'est pas un Botto" via royalty receiver
    AND pr.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    AND pr.currency_symbol IN ('ETH', 'WETH')
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, access_pass_primary AS (
    SELECT
          p.week_end
        , SUM(round((app.value * power(10, -18)),2)) as revenue
        , cast(SUM(round(round((app.value * power(10, -18)),4) / 0.03,0)) as integer) as quantity
    FROM ethereum.transactions app
    JOIN prices p
        ON app.block_time >= p.week_start AND app.block_time < p.week_end
    WHERE app.block_time >= (SELECT start_date FROM dates)
    AND   app.block_time < (SELECT end_date FROM dates)
    AND "to" = 0x6802df79bcbbf019fe5cb366ff25720d1365cfd3
    AND app.success = true
    AND app.value <> 0
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, access_pass_secondary AS (
    SELECT
          p.week_end
        , SUM(aps.royalty_fee_amount) as revenue
        , cast(SUM(aps.number_of_items) as integer) as quantity
    FROM nft.fees aps
    JOIN prices p
        ON aps.block_time >= p.week_start AND aps.block_time < p.week_end
    WHERE aps.block_time >= (SELECT start_date FROM dates)
    AND   aps.block_time < (SELECT end_date FROM dates)
    AND aps.nft_contract_address = 0x6802df79bcbbf019fe5cb366ff25720d1365cfd3
    AND 0x9b627af2a48f2e07beeeb82141e3ac6e231326bf NOT IN (aps.tx_from, aps.tx_to)
    AND aps.royalty_fee_receive_address = 0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49
    AND aps.royalty_fee_currency_symbol IN ('ETH','WETH')
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
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
    ORDER BY p.week_end DESC
)

, weekly AS (
    SELECT
          p.week
        , p.week_number
        , p.week_period
        , p.week_end
        , p.week_start
        
        -- Aggregated Sales and Quantity
        , COALESCE(SUM(CASE WHEN b.period = 'genesis' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as genesis_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'genesis' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as genesis_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'genesis' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as genesis_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'genesis' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as genesis_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'genesis' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as genesis_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'genesis' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as genesis_secondary_quantity

        , COALESCE(SUM(CASE WHEN b.period = 'fragmentation' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as fragmentation_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'fragmentation' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as fragmentation_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'fragmentation' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as fragmentation_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'fragmentation' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as fragmentation_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'fragmentation' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as fragmentation_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'fragmentation' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as fragmentation_secondary_quantity

        , COALESCE(SUM(CASE WHEN b.period = 'paradox' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as paradox_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'paradox' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as paradox_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'paradox' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as paradox_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'paradox' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as paradox_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'paradox' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as paradox_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'paradox' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as paradox_secondary_quantity

        , COALESCE(SUM(CASE WHEN b.period = 'rebellion' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as rebellion_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'rebellion' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as rebellion_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'rebellion' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as rebellion_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'rebellion' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as rebellion_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'rebellion' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as rebellion_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'rebellion' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as rebellion_secondary_quantity

        , COALESCE(SUM(CASE WHEN b.period = 'absurdism' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as absurdism_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'absurdism' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as absurdism_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'absurdism' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as absurdism_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'absurdism' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as absurdism_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'absurdism' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as absurdism_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'absurdism' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as absurdism_secondary_quantity

        , COALESCE(SUM(CASE WHEN b.period = 'interstice' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as interstice_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'interstice' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as interstice_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'interstice' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as interstice_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'interstice' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as interstice_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'interstice' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as interstice_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'interstice' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as interstice_secondary_quantity

        , COALESCE(SUM(CASE WHEN b.period = 'temporal_echoes' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as temporal_echoes_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'temporal_echoes' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as temporal_echoes_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'temporal_echoes' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as temporal_echoes_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'temporal_echoes' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as temporal_echoes_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'temporal_echoes' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as temporal_echoes_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'temporal_echoes' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as temporal_echoes_secondary_quantity

        , COALESCE(SUM(CASE WHEN b.period = 'morphogenesis' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as morphogenesis_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'morphogenesis' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as morphogenesis_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'morphogenesis' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as morphogenesis_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'morphogenesis' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as morphogenesis_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'morphogenesis' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as morphogenesis_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'morphogenesis' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as morphogenesis_secondary_quantity

        , COALESCE(SUM(CASE WHEN b.period = 'synthetic_histories' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as synthetic_histories_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'synthetic_histories' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as synthetic_histories_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'synthetic_histories' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as synthetic_histories_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'synthetic_histories' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as synthetic_histories_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'synthetic_histories' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as synthetic_histories_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'synthetic_histories' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as synthetic_histories_secondary_quantity

        , COALESCE(SUM(CASE WHEN b.period = 'cosmic_garden' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as cosmic_garden_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'cosmic_garden' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as cosmic_garden_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'cosmic_garden' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as cosmic_garden_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'cosmic_garden' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as cosmic_garden_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'cosmic_garden' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as cosmic_garden_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'cosmic_garden' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as cosmic_garden_secondary_quantity

        , COALESCE(SUM(CASE WHEN b.period = 'liminal_thresholds' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as liminal_thresholds_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'liminal_thresholds' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as liminal_thresholds_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'liminal_thresholds' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as liminal_thresholds_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'liminal_thresholds' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as liminal_thresholds_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'liminal_thresholds' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as liminal_thresholds_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'liminal_thresholds' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as liminal_thresholds_secondary_quantity

        , COALESCE(SUM(CASE WHEN b.period = 'semantic_drift' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as semantic_drift_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'semantic_drift' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as semantic_drift_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'semantic_drift' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as semantic_drift_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'semantic_drift' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as semantic_drift_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'semantic_drift' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as semantic_drift_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'semantic_drift' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as semantic_drift_secondary_quantity

        , COALESCE(SUM(CASE WHEN b.period = 'attention_economy' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as attention_economy_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'attention_economy' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as attention_economy_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'attention_economy' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as attention_economy_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'attention_economy' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as attention_economy_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'attention_economy' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as attention_economy_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'attention_economy' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as attention_economy_secondary_quantity

        , COALESCE(SUM(CASE WHEN b.period = 'collapse_aesthetics' AND b.sale_type = 'primary' THEN b.amount_original ELSE 0 END),0) as collapse_aesthetics_primary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'collapse_aesthetics' AND b.sale_type = 'primary' THEN b.revenue ELSE 0 END),0) as collapse_aesthetics_primary_revenue
        , COALESCE(SUM(CASE WHEN b.period = 'collapse_aesthetics' AND b.sale_type = 'primary' THEN b.quantity ELSE 0 END),0) as collapse_aesthetics_primary_quantity
        , COALESCE(SUM(CASE WHEN b.period = 'collapse_aesthetics' AND b.sale_type = 'secondary' THEN b.amount_original ELSE 0 END),0) as collapse_aesthetics_secondary_sales
        , COALESCE(SUM(CASE WHEN b.period = 'collapse_aesthetics' AND b.sale_type = 'secondary' THEN b.revenue ELSE 0 END),0) as collapse_aesthetics_royalties
        , COALESCE(SUM(CASE WHEN b.period = 'collapse_aesthetics' AND b.sale_type = 'secondary' THEN b.quantity ELSE 0 END),0) as collapse_aesthetics_secondary_quantity

        -- Separate joins for aux tables
        , COALESCE(ROUND(bc.sales,4),0) as collaborations_sales
        , COALESCE(ROUND(bc.revenue,4),0) as collaborations_revenue
        , COALESCE(bc.quantity,0) as collaborations_quantity
        , ROUND(COALESCE(ps.revenue,0) + COALESCE(pr.revenue,0),4) as pipes
        , COALESCE(ps.quantity,0) + COALESCE(pr.quantity,0) as pipes_quantity
        , COALESCE(ROUND(ps.revenue,4),0) as pipe_sales
        , COALESCE(ROUND(pr.revenue,4),0) as pipe_royalties
        , COALESCE(ROUND(pr.sales,4),0) as pipe_secondary_sales
        , COALESCE(ROUND(app.revenue,4),0) as access_pass_sales
        , COALESCE(ROUND(aps.revenue,4),0) as access_pass_royalties
        , ROUND(COALESCE(app.revenue,0) + COALESCE(aps.revenue,0),4) as access_pass_total
        , COALESCE(app.quantity,0) as access_pass_primary_quantity
        , COALESCE(aps.quantity,0) as access_pass_secondary_quantity
        , COALESCE(bb.botto_burnt,0) as botto_burnt
        , AVG(p.botto_price) as botto_price
        , AVG(p.eth_to_botto) as eth_to_botto

    FROM prices p
    LEFT JOIN botto_sales_classified b
        ON b.block_time >= p.week_start AND b.block_time < p.week_end
    -- Keep auxiliary tables as joins since they are distinct/simple
    LEFT JOIN collaborations bc
        ON bc.week_end = p.week_end
    LEFT JOIN pipe_primary ps
        ON ps.week_end = p.week_end
    LEFT JOIN pipe_secondary pr
        ON pr.week_end = p.week_end
    LEFT JOIN access_pass_primary app
        ON app.week_end = p.week_end
    LEFT JOIN access_pass_secondary aps
        ON aps.week_end = p.week_end
    LEFT JOIN botto_burns bb
        ON bb.week_end = p.week_end

    GROUP BY p.week, p.week_number, p.week_period, p.week_end, p.week_start,
             bc.sales, bc.revenue, bc.quantity,
             ps.revenue, pr.sales, pr.revenue, ps.quantity, pr.quantity, app.revenue, app.quantity, aps.revenue, aps.quantity,
             bb.botto_burnt
    ORDER BY p.week_number DESC
)

, weekly_calculations AS (
    SELECT
          week, week_number, week_period, week_start, week_end
        , ROUND(genesis_primary_sales 
                + fragmentation_primary_sales 
                + paradox_primary_sales
                + rebellion_primary_sales
                + absurdism_primary_sales
                + interstice_primary_sales
                + temporal_echoes_primary_sales
                + morphogenesis_primary_sales
                + synthetic_histories_primary_sales
                + cosmic_garden_primary_sales
                + liminal_thresholds_primary_sales
                + semantic_drift_primary_sales
                + attention_economy_primary_sales
                + collapse_aesthetics_primary_sales) as botto_primary_revenue
        , ROUND(genesis_royalties 
                + fragmentation_royalties
                + paradox_royalties
                + rebellion_royalties
                + absurdism_royalties
                + interstice_royalties
                + temporal_echoes_royalties
                + morphogenesis_royalties
                + synthetic_histories_royalties
                + cosmic_garden_royalties
                + liminal_thresholds_royalties
                + semantic_drift_royalties
                + attention_economy_royalties
                + collapse_aesthetics_royalties) as botto_secondary_revenue
        , genesis_primary_revenue, genesis_primary_quantity, genesis_royalties, genesis_secondary_quantity
        , fragmentation_primary_revenue, fragmentation_primary_quantity, fragmentation_royalties, fragmentation_secondary_quantity
        , paradox_primary_revenue, paradox_primary_quantity, paradox_royalties, paradox_secondary_quantity
        , rebellion_primary_revenue, rebellion_primary_quantity, rebellion_royalties, rebellion_secondary_quantity
        , absurdism_primary_revenue, absurdism_primary_quantity, absurdism_royalties, absurdism_secondary_quantity
        , interstice_primary_revenue, interstice_primary_quantity, interstice_royalties, interstice_secondary_quantity
        , temporal_echoes_primary_revenue, temporal_echoes_primary_quantity, temporal_echoes_royalties, temporal_echoes_secondary_quantity
        , morphogenesis_primary_revenue, morphogenesis_primary_quantity, morphogenesis_royalties, morphogenesis_secondary_quantity
        , synthetic_histories_primary_revenue, synthetic_histories_primary_quantity, synthetic_histories_royalties, synthetic_histories_secondary_quantity
        , cosmic_garden_primary_revenue, cosmic_garden_primary_quantity, cosmic_garden_royalties, cosmic_garden_secondary_quantity
        , liminal_thresholds_primary_revenue, liminal_thresholds_primary_quantity, liminal_thresholds_royalties, liminal_thresholds_secondary_quantity
        , semantic_drift_primary_revenue, semantic_drift_primary_quantity, semantic_drift_royalties, semantic_drift_secondary_quantity
        , attention_economy_primary_revenue, attention_economy_primary_quantity, attention_economy_royalties, attention_economy_secondary_quantity
        , collapse_aesthetics_primary_revenue, collapse_aesthetics_primary_quantity, collapse_aesthetics_royalties, collapse_aesthetics_secondary_quantity
        , collaborations_revenue, collaborations_quantity
        , pipes, pipes_quantity, pipe_sales, pipe_royalties
        , access_pass_total, access_pass_sales, access_pass_royalties, access_pass_primary_quantity, access_pass_secondary_quantity
        , ROUND(genesis_primary_revenue + genesis_royalties 
                + fragmentation_primary_revenue + fragmentation_royalties
                + paradox_primary_revenue + paradox_royalties
                + rebellion_primary_revenue + rebellion_royalties
                + absurdism_primary_revenue + absurdism_royalties
                + interstice_primary_revenue + interstice_royalties
                + temporal_echoes_primary_revenue + temporal_echoes_royalties
                + morphogenesis_primary_revenue + morphogenesis_royalties
                + synthetic_histories_primary_revenue + synthetic_histories_royalties
                + cosmic_garden_primary_revenue + cosmic_garden_royalties
                + liminal_thresholds_primary_revenue + liminal_thresholds_royalties
                + semantic_drift_primary_revenue + semantic_drift_royalties
                + attention_economy_primary_revenue + attention_economy_royalties
                + collapse_aesthetics_primary_revenue + collapse_aesthetics_royalties
                + collaborations_revenue + pipe_sales + pipe_royalties + access_pass_sales + access_pass_royalties,4) as total_revenue
        , CASE
            WHEN week_start < TIMESTAMP '2022-04-19 22:00:00'
                THEN 0
            WHEN week_start >= TIMESTAMP '2022-04-19 22:00:00' AND week_start < TIMESTAMP '2022-11-01 22:00:00'
                THEN ROUND(genesis_primary_revenue + genesis_royalties 
                        + fragmentation_primary_revenue + fragmentation_royalties
                        + collaborations_revenue + pipe_sales + pipe_royalties + access_pass_sales + access_pass_royalties,4)
            WHEN week_start >= TIMESTAMP '2022-11-01 22:00:00' 
                THEN ROUND((genesis_primary_revenue + genesis_royalties 
                        + fragmentation_primary_revenue + fragmentation_royalties
                        + paradox_primary_revenue + paradox_royalties
                        + rebellion_primary_revenue + rebellion_royalties
                        + absurdism_primary_revenue + absurdism_royalties
                        + interstice_primary_revenue + interstice_royalties
                        + temporal_echoes_primary_revenue + temporal_echoes_royalties
                        + morphogenesis_primary_revenue + morphogenesis_royalties
                        + synthetic_histories_primary_revenue + synthetic_histories_royalties
                        + cosmic_garden_primary_revenue + cosmic_garden_royalties
                        + liminal_thresholds_primary_revenue + liminal_thresholds_royalties
                        + semantic_drift_primary_revenue + semantic_drift_royalties
                        + attention_economy_primary_revenue + attention_economy_royalties
                        + collapse_aesthetics_primary_revenue + collapse_aesthetics_royalties
                        + collaborations_revenue + pipe_sales + pipe_royalties + access_pass_sales + access_pass_royalties) * 0.5, 4)
          END as treasury_allocation
        , CASE
            WHEN week_start < TIMESTAMP '2022-11-01 22:00:00' 
                THEN 0
            WHEN week_start >= TIMESTAMP '2022-11-01 22:00:00' AND week_start < TIMESTAMP '2023-05-30 22:00:00'
                THEN ROUND((genesis_primary_revenue + genesis_royalties 
                        + fragmentation_primary_revenue + fragmentation_royalties
                        + collaborations_revenue + pipe_sales + pipe_royalties + access_pass_sales + access_pass_royalties) * 0.25, 4)
            WHEN week_start >= TIMESTAMP '2023-05-30 22:00:00' 
                THEN ROUND((genesis_primary_revenue + genesis_royalties 
                        + fragmentation_primary_revenue + fragmentation_royalties
                        + paradox_primary_revenue + paradox_royalties
                        + rebellion_primary_revenue + rebellion_royalties
                        + absurdism_primary_revenue + absurdism_royalties
                        + interstice_primary_revenue + interstice_royalties
                        + temporal_echoes_primary_revenue + temporal_echoes_royalties
                        + morphogenesis_primary_revenue + morphogenesis_royalties
                        + synthetic_histories_primary_revenue + synthetic_histories_royalties
                        + cosmic_garden_primary_revenue + cosmic_garden_royalties
                        + liminal_thresholds_primary_revenue + liminal_thresholds_royalties
                        + semantic_drift_primary_revenue + semantic_drift_royalties
                        + attention_economy_primary_revenue + attention_economy_royalties
                        + collapse_aesthetics_primary_revenue + collapse_aesthetics_royalties
                        + collaborations_revenue + pipe_sales + pipe_royalties + access_pass_sales + access_pass_royalties) * 0.5, 4)
          END as active_rewards
        , CASE
            WHEN week_start < TIMESTAMP '2022-11-01 22:00:00'
                THEN 0
            WHEN week_start >= TIMESTAMP '2022-11-01 22:00:00' AND week_start < TIMESTAMP '2023-05-30 22:00:00'
                THEN ROUND((genesis_primary_revenue + genesis_royalties 
                        + fragmentation_primary_revenue + fragmentation_royalties
                        + collaborations_revenue + pipe_sales + pipe_royalties + access_pass_sales + access_pass_royalties) * 0.25, 4)
            WHEN week_start >= TIMESTAMP '2023-05-30 22:00:00'
                THEN 0
          END as retroactive_rewards
        , botto_price
        , botto_burnt
    FROM weekly
    ORDER BY week_number ASC
)

, weekly_aggregated AS (
    SELECT
          a.week
        , a.week_number
        , ROUND(SUM(b.pipes),4) as pipe_aggregated
        , ROUND(SUM(b.access_pass_total),4) as access_pass_aggregated
        , ROUND(SUM(b.botto_primary_revenue + b.botto_secondary_revenue + b.collaborations_revenue + b.pipes + b.access_pass_sales + b.access_pass_royalties),4) as revenue_aggregated
        , ROUND(SUM(b.active_rewards),4) as active_rewards_aggregated
        , ROUND(SUM(b.retroactive_rewards),4) as retroactive_rewards_aggregated
        , ROUND(SUM(b.botto_burnt),4) as botto_burnt_aggregated
    FROM weekly a
    LEFT JOIN weekly_calculations b
        ON b.week_number <= a.week_number
    GROUP BY a.week, a.week_number
    ORDER BY a.week_number ASC
)

SELECT
      wc.*
    , wa.pipe_aggregated
    , wa.access_pass_aggregated
    , wa.revenue_aggregated
    , wa.active_rewards_aggregated
    , wa.retroactive_rewards_aggregated
    , wa.botto_burnt_aggregated
FROM weekly_calculations wc
LEFT JOIN weekly_aggregated wa
    ON wc.week = wa.week
ORDER BY wc.week_number DESC