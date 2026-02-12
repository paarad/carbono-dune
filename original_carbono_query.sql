WITH dates AS (
    SELECT
        cast('2021-10-19 22:00' as timestamp) as start_date,
        current_timestamp as end_date
)

, prices AS (
    SELECT
          date_trunc('hour', eth.minute) as week_end
        , date_trunc('hour', eth.minute - INTERVAL '7' DAY) as week_start
        , concat(cast(row_number() OVER (ORDER BY eth.minute ASC) as varchar),
            ' (',format_datetime(date_trunc('hour', eth.minute - INTERVAL '7' DAY),'yyyy-MM-dd H:mm'),
            ' to ',format_datetime(date_trunc('hour', eth.minute),'yyyy-MM-dd H:mm'),')') as week
        , (row_number() OVER (ORDER BY eth.minute ASC)) as week_number
        , concat(format_datetime(date_trunc('hour', eth.minute - INTERVAL '7' DAY),'yyyy-MM-dd H:mm'),
            ' to ',format_datetime(date_trunc('hour', eth.minute),'yyyy-MM-dd H:mm')) as week_period
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
        AND HOUR(botto.minute) = 22
        AND MINUTE(botto.minute) = 0
    ORDER BY week_end DESC
)

/*, botto_primary AS (
    SELECT
          p.week_end
        , SUM(bp.amount_original * 0.85) as revenue
        , SUM(bp.number_of_items) as quantity
    FROM superrare.events bp
    LEFT JOIN prices p
        ON bp.block_time >= p.week_start AND bp.block_time < p.week_end
    WHERE bp.block_time >= (SELECT start_date FROM dates)
    AND   bp.block_time < (SELECT end_date FROM dates)
    AND bp.seller IN  (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                        0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    --Check collections:
    AND (
        --Collection = Genesis
        bp.nft_contract_address = 0xb932a70a57673d89f4acffbe830e8ed7f75fb9e0
        AND cast(bp.token_id as varchar) IN (
            SELECT token_id
            FROM nft.mints
            WHERE tx_from = 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c
            AND collection = 'SuperRare'
            ORDER by token_id ASC)
        OR 
        --Collection <> Genesis
        bp.nft_contract_address IN (
            SELECT DISTINCT nft_contract_address
            FROM nft.mints
            WHERE tx_from = 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c
            AND nft_contract_address NOT IN 
                (0xb932a70a57673d89f4acffbe830e8ed7f75fb9e0,
                0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85)
        )
    )
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, botto_secondary AS (
    SELECT
          p.week_end
        , SUM(bs.amount_original / COALESCE(bs.royalty_fee_percentage,10)) as revenue
        , SUM(bs.number_of_items) as quantity
    FROM superrare.events bs
    LEFT JOIN prices p
        ON bs.block_time >= p.week_start AND bs.block_time < p.week_end
    WHERE bs.block_time >= (SELECT start_date FROM dates)
    AND   bs.block_time < (SELECT end_date FROM dates)
    AND bs.seller NOT IN  (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                            0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    --Check collections:
    AND (
        --Collection = Genesis
        bs.nft_contract_address = 0xb932a70a57673d89f4acffbe830e8ed7f75fb9e0
        AND cast(bs.token_id as varchar) IN (
            SELECT token_id
            FROM nft.mints
            WHERE tx_from = 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c
            AND collection = 'SuperRare'
            ORDER by token_id ASC)
        OR 
        --Collection <> Genesis
        bs.nft_contract_address IN (
            SELECT DISTINCT nft_contract_address
            FROM nft.mints
            WHERE tx_from = 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c
            AND nft_contract_address NOT IN 
                (0xb932a70a57673d89f4acffbe830e8ed7f75fb9e0,
                0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85)
        )
    )
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)*/

, genesis_primary AS (
    SELECT
          p.week_end
        , SUM(b1p.amount_original) as sales
        , SUM(b1p.amount_original * 0.85) as revenue
        , SUM(b1p.number_of_items) as quantity
    FROM superrare.events b1p
    JOIN prices p
        ON b1p.block_time >= p.week_start AND b1p.block_time < p.week_end
    WHERE b1p.block_time >= (SELECT start_date FROM dates)
    AND   b1p.block_time < (SELECT end_date FROM dates)
    --Filtering to only Botto from Genesis period:
    AND b1p.nft_contract_address = 0xb932a70a57673d89f4acffbe830e8ed7f75fb9e0
    AND cast(b1p.token_id as varchar) IN 
        ('29715', '29922', '30114', '30298', '30443', '30639', '30887', '31057', '31200', '31352', '31447',
        '31546', '31704', '31887', '32068', '32242', '32457', '32619', '32737', '33018', '33163', '33332',
        '33501', '33637', '33754', '33879', '34066', '34231', '34399', '34540', '34684', '34910', '35069',
        '35208', '35353', '35482', '35616', '35769', '35934', '36127', '36315', '36525', '36702', '36905',
        '37149', '37380', '37657', '37877', '38050', '38335', '38615', '38913')
    --Filtering to only primary sales:
    AND b1p.seller IN  (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                        0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, genesis_secondary AS (
    SELECT
          p.week_end
        , SUM(b1s.amount_original) as sales
        , SUM(b1s.amount_original / COALESCE(b1s.royalty_fee_percentage,10)) as revenue
        , SUM(b1s.number_of_items) as quantity
    FROM superrare.events b1s
    JOIN prices p
        ON b1s.block_time >= p.week_start AND b1s.block_time < p.week_end
    WHERE b1s.block_time >= (SELECT start_date FROM dates)
    AND   b1s.block_time < (SELECT end_date FROM dates)
    --Filtering to only Botto from Genesis period:
    AND b1s.nft_contract_address = 0xb932a70a57673d89f4acffbe830e8ed7f75fb9e0
    AND cast(b1s.token_id as varchar) IN 
        ('29715', '29922', '30114', '30298', '30443', '30639', '30887', '31057', '31200', '31352', '31447',
        '31546', '31704', '31887', '32068', '32242', '32457', '32619', '32737', '33018', '33163', '33332',
        '33501', '33637', '33754', '33879', '34066', '34231', '34399', '34540', '34684', '34910', '35069',
        '35208', '35353', '35482', '35616', '35769', '35934', '36127', '36315', '36525', '36702', '36905',
        '37149', '37380', '37657', '37877', '38050', '38335', '38615', '38913')
    --Filtering to only secondary sales:
    AND b1s.seller NOT IN (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                           0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, fragmentation_primary AS (
    SELECT
          p.week_end
        , SUM(b2p.amount_original) as sales
        , SUM(b2p.amount_original * 0.85) as revenue
        , SUM(b2p.number_of_items) as quantity
    FROM superrare.events b2p
    JOIN prices p
        ON b2p.block_time >= p.week_start AND b2p.block_time < p.week_end
    WHERE b2p.block_time >= (SELECT start_date FROM dates)
    AND   b2p.block_time < (SELECT end_date FROM dates)
    --Filtering to only Botto from Fragmentation period:
    AND b2p.nft_contract_address = 0xa4dc93da01458d38f691db5c98e9157891febe86
    --Filtering to only primary sales:
    AND b2p.seller IN  (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                        0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, fragmentation_secondary AS (
    SELECT
          p.week_end
        , SUM(b2s.amount_original) as sales
        , SUM(b2s.amount_original / COALESCE(b2s.royalty_fee_percentage,10)) as revenue
        , SUM(b2s.number_of_items) as quantity
    FROM superrare.events b2s
    JOIN prices p
        ON b2s.block_time >= p.week_start AND b2s.block_time < p.week_end
    WHERE b2s.block_time >= (SELECT start_date FROM dates)
    AND   b2s.block_time < (SELECT end_date FROM dates)
    --Filtering to only Botto from Fragmentation period:
    AND b2s.nft_contract_address = 0xa4dc93da01458d38f691db5c98e9157891febe86
    --Filtering to only secondary sales:
    AND b2s.seller NOT IN  (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                            0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, paradox_primary AS (
    SELECT
          p.week_end
        , SUM(b3p.amount_original) as sales
        , SUM(b3p.amount_original * 0.85) as revenue
        , SUM(b3p.number_of_items) as quantity
    FROM superrare.events b3p
    JOIN prices p
        ON b3p.block_time >= p.week_start AND b3p.block_time < p.week_end
    WHERE b3p.block_time >= (SELECT start_date FROM dates)
    AND   b3p.block_time < (SELECT end_date FROM dates)
    --Filtering to only Botto from Paradox period:
    AND b3p.nft_contract_address = 0xbdf4f17b7d638d7d3e5dcadf27e812b07b2b5c9e
    --Filtering to only primary sales:
    AND b3p.seller IN  (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                        0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, paradox_secondary AS (
    SELECT
          p.week_end
        , SUM(b3s.amount_original) as sales
        , SUM(b3s.amount_original / COALESCE(b3s.royalty_fee_percentage,10)) as revenue
        , SUM(b3s.number_of_items) as quantity
    FROM superrare.events b3s
    JOIN prices p
        ON b3s.block_time >= p.week_start AND b3s.block_time < p.week_end
    WHERE b3s.block_time >= (SELECT start_date FROM dates)
    AND   b3s.block_time < (SELECT end_date FROM dates)
    --Filtering to only Botto from Paradox period:
    AND b3s.nft_contract_address = 0xbdf4f17b7d638d7d3e5dcadf27e812b07b2b5c9e
    --Filtering to only secondary sales:
    AND b3s.seller NOT IN  (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                            0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, rebellion_primary AS (
    SELECT
          p.week_end
        , SUM(b4p.amount_original) as sales
        , SUM(b4p.amount_original * 0.85) as revenue
        , cast(SUM(b4p.number_of_items) as integer) as quantity
    FROM nft.trades b4p
    JOIN prices p
        ON b4p.block_time >= p.week_start AND b4p.block_time < p.week_end
    WHERE b4p.block_time >= (SELECT start_date FROM dates)
    AND   b4p.block_time < (SELECT end_date FROM dates)
    --Filtering to only Botto from Rebellion period:
    AND b4p.nft_contract_address = 0x1c7576619032eaf8b8a938c352e535bba92a366c
    --Filtering to only primary sales:
    AND b4p.seller IN  (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                        0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, rebellion_secondary AS (
    SELECT
          p.week_end
        , SUM(b4s.amount_original) as sales
        , SUM(b4s.amount_original / 10) as revenue
        , cast(SUM(b4s.number_of_items) as integer) as quantity
    FROM nft.trades b4s
    JOIN prices p
        ON b4s.block_time >= p.week_start AND b4s.block_time < p.week_end
    WHERE b4s.block_time >= (SELECT start_date FROM dates)
    AND   b4s.block_time < (SELECT end_date FROM dates)
    --Filtering to only Botto from Rebellion period:
    AND b4s.nft_contract_address = 0x1c7576619032eaf8b8a938c352e535bba92a366c
    --Filtering to only secondary sales:
    AND b4s.seller NOT IN  (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                            0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, absurdism_primary AS (
    SELECT
          p.week_end
        , SUM(b5p.amount_original) as sales
        , SUM(b5p.amount_original * 0.85) as revenue
        , cast(SUM(b5p.number_of_items) as integer) as quantity
    FROM nft.trades b5p
    JOIN prices p
        ON b5p.block_time >= p.week_start AND b5p.block_time < p.week_end
    WHERE b5p.block_time >= (SELECT start_date FROM dates)
    AND   b5p.block_time < (SELECT end_date FROM dates)
    --Filtering to only Botto from Absurdism period:
    AND b5p.nft_contract_address = 0x47542736c9d1086dc87cc45138b2d57ec79eafa3
    --Filtering to only primary sales:
    AND b5p.seller IN  (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                        0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, absurdism_secondary AS (
    SELECT
          p.week_end
        , SUM(b5s.amount_original) as sales
        , SUM(b5s.amount_original / 10) as revenue
        , cast(SUM(b5s.number_of_items) as integer) as quantity
    FROM nft.trades b5s
    JOIN prices p
        ON b5s.block_time >= p.week_start AND b5s.block_time < p.week_end
    WHERE b5s.block_time >= (SELECT start_date FROM dates)
    AND   b5s.block_time < (SELECT end_date FROM dates)
    --Filtering to only Botto from Absurdism period:
    AND b5s.nft_contract_address = 0x47542736c9d1086dc87cc45138b2d57ec79eafa3
    --Filtering to only secondary sales:
    AND b5s.seller NOT IN  (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                            0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, botto2024_primary AS (
    SELECT
          bp2024.block_time
        , bp2024.amount_original as sales
        , (bp2024.amount_original * 0.85) as revenue
        , cast(bp2024.number_of_items as integer) as quantity
        , token_id
    FROM nft.trades bp2024
    WHERE bp2024.block_time >= (SELECT start_date FROM dates)
    AND   bp2024.block_time < (SELECT end_date FROM dates)
    --Filtering to only Botto from Interstice period:
    AND bp2024.nft_contract_address = 0xca53bb6cdfcd5bf437bf4ac6d17c3b0e67d8a83e
    --Filtering to only primary sales:
    AND bp2024.seller IN  (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                        0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    ORDER BY bp2024.block_time DESC
)

, botto2024_secondary AS (
    SELECT
          bs2024.block_time
        , bs2024.amount_original as sales
        , (bs2024.amount_original / 10) as revenue
        , cast(bs2024.number_of_items as integer) as quantity
        , token_id
    FROM nft.trades bs2024
    WHERE bs2024.block_time >= (SELECT start_date FROM dates)
    AND   bs2024.block_time < (SELECT end_date FROM dates)
    --Filtering to only Botto from Interstice period:
    AND bs2024.nft_contract_address = 0xca53bb6cdfcd5bf437bf4ac6d17c3b0e67d8a83e
    --Filtering to only secondary sales:
    AND bs2024.seller NOT IN  (0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
                            0x8c9f364bf7a56ed058fc63ef81c6cf09c833e656)
    ORDER BY bs2024.block_time DESC
)

, interstice_primary AS (
    SELECT
          p.week_end
        , SUM(sales) as sales
        , SUM(revenue) as revenue
        , SUM(quantity) as quantity
    FROM botto2024_primary
    JOIN prices p
        ON block_time >= p.week_start AND block_time < p.week_end
    WHERE token_id >= 1 AND token_id <= 13
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, interstice_secondary AS (
    SELECT
          p.week_end
        , SUM(sales) as sales
        , SUM(revenue) as revenue
        , SUM(quantity) as quantity
    FROM botto2024_secondary
    JOIN prices p
        ON block_time >= p.week_start AND block_time < p.week_end
    WHERE token_id >= 1 AND token_id <= 13
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, temporal_echoes_primary AS (
    SELECT
          p.week_end
        , SUM(sales) as sales
        , SUM(revenue) as revenue
        , SUM(quantity) as quantity
    FROM botto2024_primary
    JOIN prices p
        ON block_time >= p.week_start AND block_time < p.week_end
    WHERE token_id > 13 AND token_id <= 26
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, temporal_echoes_secondary AS (
    SELECT
          p.week_end
        , SUM(sales) as sales
        , SUM(revenue) as revenue
        , SUM(quantity) as quantity
    FROM botto2024_secondary
    JOIN prices p
        ON block_time >= p.week_start AND block_time < p.week_end
    WHERE token_id > 13 AND token_id <= 26
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, morphogenesis_primary AS (
    SELECT
          p.week_end
        , SUM(sales) as sales
        , SUM(revenue) as revenue
        , SUM(quantity) as quantity
    FROM botto2024_primary
    JOIN prices p
        ON block_time >= p.week_start AND block_time < p.week_end
    WHERE token_id > 26 AND token_id <= 39
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

, morphogenesis_secondary AS (
    SELECT
          p.week_end
        , SUM(sales) as sales
        , SUM(revenue) as revenue
        , SUM(quantity) as quantity
    FROM botto2024_secondary
    JOIN prices p
        ON block_time >= p.week_start AND block_time < p.week_end
    WHERE token_id > 26 AND token_id <= 39
    GROUP BY p.week_end
    ORDER BY p.week_end DESC
)

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
        , SUM(cast(json_query(ps.permit_, 'lax$.minimumPrice') as double) * power(10, -18)) as revenue
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
    FROM opensea.events pr
    JOIN prices p
        ON pr.block_time >= p.week_start AND pr.block_time < p.week_end
    WHERE pr.block_time >= (SELECT start_date FROM dates)
    AND   pr.block_time < (SELECT end_date FROM dates)
    AND pr.collection = U&'Ceci n\0027est pas un Botto'
    -- There exists another royalty_fee_receive_address for "Ceci n'est pas un Botto", 
    -- should I include it?
    -- '0x5b3256965e7c3cf26e11fcaf296dfc8807c01073'
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
        /*, COALESCE(ROUND(bp.revenue,4),0) as botto_primary_revenue
        , COALESCE(ROUND(bp.sales,4),0) as botto_primary_sales
        , COALESCE(ROUND(bs.revenue,4),0) as botto_secondary_revenue
        , COALESCE(ROUND(bs.sales,4),0) as botto_secondary_sales*/
        , COALESCE(ROUND(b1p.sales,4),0) as genesis_primary_sales
        , COALESCE(ROUND(b1p.revenue,4),0) as genesis_primary_revenue
        , COALESCE(b1p.quantity,0) as genesis_primary_quantity
        , COALESCE(ROUND(b1s.sales,4),0) as genesis_secondary_sales
        , COALESCE(ROUND(b1s.revenue,4),0) as genesis_royalties
        , COALESCE(b1s.quantity,0) as genesis_secondary_quantity
        , COALESCE(ROUND(b2p.sales,4),0) as fragmentation_primary_sales
        , COALESCE(ROUND(b2p.revenue,4),0) as fragmentation_primary_revenue
        , COALESCE(b2p.quantity,0) as fragmentation_primary_quantity
        , COALESCE(ROUND(b2s.sales,4),0) as fragmentation_secondary_sales
        , COALESCE(ROUND(b2s.revenue,4),0) as fragmentation_royalties
        , COALESCE(b2s.quantity,0) as fragmentation_secondary_quantity
        , COALESCE(ROUND(b3p.sales,4),0) as paradox_primary_sales
        , COALESCE(ROUND(b3p.revenue,4),0) as paradox_primary_revenue
        , COALESCE(b3p.quantity,0) as paradox_primary_quantity
        , COALESCE(ROUND(b3s.sales,4),0) as paradox_secondary_sales
        , COALESCE(ROUND(b3s.revenue,4),0) as paradox_royalties
        , COALESCE(b3s.quantity,0) as paradox_secondary_quantity
        , COALESCE(ROUND(b4p.sales,4),0) as rebellion_primary_sales
        , COALESCE(ROUND(b4p.revenue,4),0) as rebellion_primary_revenue
        , COALESCE(b4p.quantity,0) as rebellion_primary_quantity
        , COALESCE(ROUND(b4s.sales,4),0) as rebellion_secondary_sales
        , COALESCE(ROUND(b4s.revenue,4),0) as rebellion_royalties
        , COALESCE(b4s.quantity,0) as rebellion_secondary_quantity
        , COALESCE(ROUND(b5p.sales,4),0) as absurdism_primary_sales
        , COALESCE(ROUND(b5p.revenue,4),0) as absurdism_primary_revenue
        , COALESCE(b5p.quantity,0) as absurdism_primary_quantity
        , COALESCE(ROUND(b5s.sales,4),0) as absurdism_secondary_sales
        , COALESCE(ROUND(b5s.revenue,4),0) as absurdism_royalties
        , COALESCE(b5s.quantity,0) as absurdism_secondary_quantity
        , COALESCE(ROUND(b6p.sales,4),0) as interstice_primary_sales
        , COALESCE(ROUND(b6p.revenue,4),0) as interstice_primary_revenue
        , COALESCE(b6p.quantity,0) as interstice_primary_quantity
        , COALESCE(ROUND(b6s.sales,4),0) as interstice_secondary_sales
        , COALESCE(ROUND(b6s.revenue,4),0) as interstice_royalties
        , COALESCE(b6s.quantity,0) as interstice_secondary_quantity
        , COALESCE(ROUND(b7p.sales,4),0) as temporal_echoes_primary_sales
        , COALESCE(ROUND(b7p.revenue,4),0) as temporal_echoes_primary_revenue
        , COALESCE(b7p.quantity,0) as temporal_echoes_primary_quantity
        , COALESCE(ROUND(b7s.sales,4),0) as temporal_echoes_secondary_sales
        , COALESCE(ROUND(b7s.revenue,4),0) as temporal_echoes_royalties
        , COALESCE(b7s.quantity,0) as temporal_echoes_secondary_quantity
        , COALESCE(ROUND(b8p.sales,4),0) as morphogenesis_primary_sales
        , COALESCE(ROUND(b8p.revenue,4),0) as morphogenesis_primary_revenue
        , COALESCE(b8p.quantity,0) as morphogenesis_primary_quantity
        , COALESCE(ROUND(b8s.sales,4),0) as morphogenesis_secondary_sales
        , COALESCE(ROUND(b8s.revenue,4),0) as morphogenesis_royalties
        , COALESCE(b8s.quantity,0) as morphogenesis_secondary_quantity
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
    /*LEFT JOIN botto_primary bp
        ON bp.week_end = p.week_end
    LEFT JOIN botto_secondary bs
        ON bs.week_end = p.week_end*/
    LEFT JOIN genesis_primary b1p
        ON b1p.week_end = p.week_end
    LEFT JOIN genesis_secondary b1s
        ON b1s.week_end = p.week_end
    LEFT JOIN fragmentation_primary b2p
        ON b2p.week_end = p.week_end
    LEFT JOIN fragmentation_secondary b2s
        ON b2s.week_end = p.week_end
    LEFT JOIN paradox_primary b3p
        ON b3p.week_end = p.week_end
    LEFT JOIN paradox_secondary b3s
        ON b3s.week_end = p.week_end
    LEFT JOIN rebellion_primary b4p
        ON b4p.week_end = p.week_end
    LEFT JOIN rebellion_secondary b4s
        ON b4s.week_end = p.week_end
    LEFT JOIN absurdism_primary b5p
        ON b5p.week_end = p.week_end
    LEFT JOIN absurdism_secondary b5s
        ON b5s.week_end = p.week_end
    LEFT JOIN interstice_primary b6p
        ON b6p.week_end = p.week_end
    LEFT JOIN interstice_secondary b6s
        ON b6s.week_end = p.week_end
    LEFT JOIN temporal_echoes_primary b7p
        ON b7p.week_end = p.week_end
    LEFT JOIN temporal_echoes_secondary b7s
        ON b7s.week_end = p.week_end
    LEFT JOIN morphogenesis_primary b8p
        ON b8p.week_end = p.week_end
    LEFT JOIN morphogenesis_secondary b8s
        ON b8s.week_end = p.week_end
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
    GROUP BY p.week, p.week_number, p.week_period, p.week_end, p.week_start, p.botto_price, p.eth_to_botto, bb.botto_burnt,
             /*bp.sales, bs.sales, bp.revenue, bs.revenue,*/ 
             b1p.sales, b1s.sales, b1p.revenue, b1s.revenue, b1p.quantity, b1s.quantity,
             b2p.sales, b2s.sales, b2p.revenue, b2s.revenue, b2p.quantity, b2s.quantity,
             b3p.sales, b3s.sales, b3p.revenue, b3s.revenue, b3p.quantity, b3s.quantity,
             b4p.sales, b4s.sales, b4p.revenue, b4s.revenue, b4p.quantity, b4s.quantity,
             b5p.sales, b5s.sales, b5p.revenue, b5s.revenue, b5p.quantity, b5s.quantity,
             b6p.sales, b6s.sales, b6p.revenue, b6s.revenue, b6p.quantity, b6s.quantity,
             b7p.sales, b7s.sales, b7p.revenue, b7s.revenue, b7p.quantity, b7s.quantity,
             b8p.sales, b8s.sales, b8p.revenue, b8s.revenue, b8p.quantity, b8s.quantity,
             bc.sales, bc.revenue, bc.quantity,
             ps.revenue, pr.sales, pr.revenue, ps.quantity, pr.quantity, app.revenue, app.quantity, aps.revenue, aps.quantity
    ORDER BY p.week_number ASC
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
                + morphogenesis_primary_sales) as botto_primary_revenue
        , ROUND(genesis_royalties 
                + fragmentation_royalties
                + paradox_royalties
                + rebellion_royalties
                + absurdism_royalties
                + interstice_royalties
                + temporal_echoes_royalties
                + morphogenesis_royalties) as botto_secondary_revenue
        , genesis_primary_revenue, genesis_primary_quantity, genesis_royalties, genesis_secondary_quantity
        , fragmentation_primary_revenue, fragmentation_primary_quantity, fragmentation_royalties, fragmentation_secondary_quantity
        , paradox_primary_revenue, paradox_primary_quantity, paradox_royalties, paradox_secondary_quantity
        , rebellion_primary_revenue, rebellion_primary_quantity, rebellion_royalties, rebellion_secondary_quantity
        , absurdism_primary_revenue, absurdism_primary_quantity, absurdism_royalties, absurdism_secondary_quantity
        , interstice_primary_revenue, interstice_primary_quantity, interstice_royalties, interstice_secondary_quantity
        , temporal_echoes_primary_revenue, temporal_echoes_primary_quantity, temporal_echoes_royalties, temporal_echoes_secondary_quantity
        , morphogenesis_primary_revenue, morphogenesis_primary_quantity, morphogenesis_royalties, morphogenesis_secondary_quantity
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
                + collaborations_revenue + pipe_sales + pipe_royalties + access_pass_sales + access_pass_royalties,4) as total_revenue
        , CASE
            WHEN week_start < cast('2022-04-19 22:00' as timestamp)
                THEN 0
            WHEN week_start >= cast('2022-04-19 22:00' as timestamp) AND week_start < cast('2022-11-01 22:00' as timestamp)
                THEN ROUND(genesis_primary_revenue + genesis_royalties 
                        + fragmentation_primary_revenue + fragmentation_royalties
                        + collaborations_revenue + pipe_sales + pipe_royalties + access_pass_sales + access_pass_royalties,4)
            WHEN week_start >= cast('2022-11-01 22:00' as timestamp) 
                THEN ROUND((genesis_primary_revenue + genesis_royalties 
                        + fragmentation_primary_revenue + fragmentation_royalties
                        + paradox_primary_revenue + paradox_royalties
                        + rebellion_primary_revenue + rebellion_royalties
                        + absurdism_primary_revenue + absurdism_royalties
                        + interstice_primary_revenue + interstice_royalties
                        + temporal_echoes_primary_revenue + temporal_echoes_royalties
                        + morphogenesis_primary_revenue + morphogenesis_royalties
                        + collaborations_revenue + pipe_sales + pipe_royalties + access_pass_sales + access_pass_royalties) * 0.5, 4)
          END as treasury_allocation
        , CASE
            WHEN week_start < cast('2022-11-01 22:00' as timestamp) 
                THEN 0
            WHEN week_start >= cast('2022-11-01 22:00' as timestamp) AND week_start < cast('2023-05-30 22:00' as timestamp)
                THEN ROUND((genesis_primary_revenue + genesis_royalties 
                        + fragmentation_primary_revenue + fragmentation_royalties
                        + collaborations_revenue + pipe_sales + pipe_royalties + access_pass_sales + access_pass_royalties) * 0.25, 4)
            WHEN week_start >= cast('2023-05-30 22:00' as timestamp) 
                THEN ROUND((genesis_primary_revenue + genesis_royalties 
                        + fragmentation_primary_revenue + fragmentation_royalties
                        + paradox_primary_revenue + paradox_royalties
                        + rebellion_primary_revenue + rebellion_royalties
                        + absurdism_primary_revenue + absurdism_royalties
                        + interstice_primary_revenue + interstice_royalties
                        + temporal_echoes_primary_revenue + temporal_echoes_royalties
                        + morphogenesis_primary_revenue + morphogenesis_royalties
                        + collaborations_revenue + pipe_sales + pipe_royalties + access_pass_sales + access_pass_royalties) * 0.5, 4)
          END as active_rewards
        , CASE
            WHEN week_start < cast('2022-11-01 22:00' as timestamp)
                THEN 0
            WHEN week_start >= cast('2022-11-01 22:00' as timestamp) AND week_start < cast('2023-05-30 22:00' as timestamp)
                THEN ROUND((genesis_primary_revenue + genesis_royalties 
                        + fragmentation_primary_revenue + fragmentation_royalties
                        + collaborations_revenue + pipe_sales + pipe_royalties + access_pass_sales + access_pass_royalties) * 0.25, 4)
            WHEN week_start >= cast('2023-05-30 22:00' as timestamp)
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