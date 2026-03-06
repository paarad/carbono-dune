-- ============================================================
-- Botto NFT Sales (rewrite of external project query 6567147)
-- ============================================================
-- Original query only used nft.trades, which misses
-- SuperRare BatchOfferCreator sales. This version adds them.
-- Parameters: {{contract_address}}, {{from_block}}, {{to_block}}
-- ============================================================

with params as (
  select
    from_hex(replace(cast({{contract_address}} as varchar), '0x', '')) as contract_addr
)

-- BatchOfferCreator sales (not captured by nft.trades)
-- Detects sale events from the log topic, gets ETH amount from tx value
, batch_offer_events AS (
    SELECT
        l.block_time,
        l.block_number,
        l.tx_hash,
        bytearray_substring(l.topic1, 13, 20) as seller,
        bytearray_substring(l.topic3, 13, 20) as nft_contract_address,
        bytearray_to_uint256(bytearray_substring(l.data, 1, 32)) as token_id
    FROM ethereum.logs l
    CROSS JOIN params p
    WHERE l.topic0 = 0x25d87e12d2953b43b0140bdfc8a4fa389293a8d350e9becd3e21d6646620fa72
      AND bytearray_substring(l.topic3, 13, 20) = p.contract_addr
      AND l.block_number >= {{from_block}}
      AND l.block_number <= {{to_block}}
)

, batch_offer_sales AS (
    SELECT
        b.block_number,
        b.block_time,
        b.tx_hash,
        b.nft_contract_address,
        b.token_id,
        tx."from" as buyer,
        b.seller,
        1 as number_of_items,
        CAST(tx.value AS double) / 1e18 as amount_original,
        CAST(tx.value AS double) / 1e18 * ep.price as amount_usd,
        0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee as currency_contract,
        'ETH' as currency_symbol
    FROM batch_offer_events b
    JOIN ethereum.transactions tx
        ON tx.hash = b.tx_hash
        AND tx.block_number = b.block_number
    LEFT JOIN prices.usd ep
        ON ep.contract_address = 0xc02aaa39b223fe8d0a0e5c4b8d68103a3ea9782b
        AND ep.blockchain = 'ethereum'
        AND ep.minute = date_trunc('minute', b.block_time)
)

select
  s.block_number,
  s.block_time,
  s.tx_hash,

  row_number() over (
    partition by s.tx_hash
    order by cast(s.token_id as bigint)
  ) - 1 as evt_index,

  concat('0x', to_hex(s.nft_contract_address)) as contract_address,
  cast(s.token_id as varchar)                   as token_id,

  concat('0x', to_hex(s.buyer))                 as buyer,
  concat('0x', to_hex(s.seller))                as seller,

  s.number_of_items,
  s.amount_original,
  s.amount_usd,

  concat('0x', to_hex(s.currency_contract))     as currency_contract,
  s.currency_symbol

from (
    -- nft.trades (excluding batch offer txs to avoid duplicates/wrong amounts)
    select
      t.block_number,
      t.block_time,
      t.tx_hash,
      t.nft_contract_address,
      t.token_id,
      t.buyer,
      t.seller,
      t.number_of_items,
      t.amount_original,
      t.amount_usd,
      t.currency_contract,
      t.currency_symbol
    from nft.trades t
    cross join params p
    where t.blockchain = 'ethereum'
      and t.nft_contract_address = p.contract_addr
      and t.block_number >= {{from_block}}
      and t.block_number <= {{to_block}}
      and t.tx_hash not in (select tx_hash from batch_offer_events)

    union all

    -- BatchOfferCreator sales
    select
      block_number,
      block_time,
      tx_hash,
      nft_contract_address,
      token_id,
      buyer,
      seller,
      number_of_items,
      amount_original,
      amount_usd,
      currency_contract,
      currency_symbol
    from batch_offer_sales
) s
order by
  s.block_number asc,
  s.tx_hash asc,
  evt_index asc



-- old query : 
-- with params as (
--   select
--     from_hex(replace(cast({{contract_address}} as varchar), '0x', '')) as contract_addr
-- )

-- select
--   t.block_number,
--   t.block_time,
--   t.tx_hash,

--   row_number() over (
--     partition by t.tx_hash
--     order by cast(t.token_id as bigint)
--   ) - 1 as evt_index,

--   concat('0x', to_hex(t.nft_contract_address)) as contract_address,
--   cast(t.token_id as varchar)                 as token_id,

--   concat('0x', to_hex(t.buyer))               as buyer,
--   concat('0x', to_hex(t.seller))              as seller,

--   t.number_of_items,
--   t.amount_original,
--   t.amount_usd,

--   concat('0x', to_hex(t.currency_contract))   as currency_contract,
--   t.currency_symbol
-- from nft.trades t
-- cross join params p
-- where t.blockchain = 'ethereum'
--   and t.nft_contract_address = p.contract_addr
--   and t.block_number >= {{from_block}}
--   and t.block_number <= {{to_block}}
-- order by
--   t.block_number asc,
--   t.tx_hash asc,
--   evt_index asc;
