-- ============================================================
-- BOTTO DASHBOARD: Token Supply Breakdown
-- ============================================================
-- Chart: Stacked Area
-- X-axis: week_end
-- Y-series: burned, gov_staking, treasury, team, airdrop,
--           uni_v2_lp, uni_v3_lp, rewards_wallet,
--           liquidity_mining, circulating
-- ============================================================

WITH dates AS (
    SELECT
        TIMESTAMP '2021-10-05 22:00:00' as start_date,
        current_timestamp as end_date
)

-- Weekly buckets using only ETH prices (BOTTO may not have price data before trading started)
, prices AS (
    SELECT DISTINCT
          date_trunc('hour', eth.minute) as week_end
        , date_trunc('hour', eth.minute - INTERVAL '7' DAY) as week_start
    FROM prices.usd eth
    WHERE eth.contract_address = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
        AND eth.blockchain = 'ethereum'
        AND eth.minute >= (SELECT start_date + INTERVAL '7' DAY FROM dates)
        AND eth.minute <= (SELECT end_date FROM dates)
        AND day_of_week(eth.minute) = 2
        AND hour(eth.minute) = 22
        AND minute(eth.minute) = 0
)

-- Key addresses:
-- burned:           0x...dead
-- gov_staking:      0x19cd...
-- treasury:         0x35bb... (current) + 0x000a... (botto.eth initial)
-- team:             0xaf1e... (team wallet) + 3 team members
-- airdrop:          0xed39... (30M airdrop wallet)
-- uni_v2_lp:        0x9ff6...
-- uni_v3_lp:        0xd60d...
-- rewards_wallet:   0x9329...
-- liquidity_mining: 0xf851...

-- Initial balances from all transfers before our tracking window
, initial_balances AS (
    SELECT
          SUM(CASE WHEN t."to" = 0x000000000000000000000000000000000000dead THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0x000000000000000000000000000000000000dead THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as burned_init
        , SUM(CASE WHEN t."to" = 0x19cd3998f106ecc40ee7668c19c47e18b491e8a6 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0x19cd3998f106ecc40ee7668c19c47e18b491e8a6 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as gov_staking_init
        , SUM(CASE WHEN t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c) THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c) THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as treasury_init
        , SUM(CASE WHEN t."to" IN (0xaf1e1c2eb21e4b977517bc651a7046c723b49809, 0x2686b313a823f867addf697d6e67016901188076, 0xc88dff41d5e173618bba613885e9d1d062c753b7, 0xdb6ba2be3e29683ab8c9faef6a1354be8d630c2b) THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" IN (0xaf1e1c2eb21e4b977517bc651a7046c723b49809, 0x2686b313a823f867addf697d6e67016901188076, 0xc88dff41d5e173618bba613885e9d1d062c753b7, 0xdb6ba2be3e29683ab8c9faef6a1354be8d630c2b) THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as team_init
        , SUM(CASE WHEN t."to" = 0xed39dafd2b2a624fe43a5bbe76e0dae4e4e621ef THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0xed39dafd2b2a624fe43a5bbe76e0dae4e4e621ef THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as airdrop_init
        , SUM(CASE WHEN t."to" = 0x9ff68f61ca5eb0c6606dc517a9d44001e564bb66 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0x9ff68f61ca5eb0c6606dc517a9d44001e564bb66 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as uni_v2_lp_init
        , SUM(CASE WHEN t."to" = 0xd60dc6571e477fb2d96df02efd5fba9c54a4e998 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0xd60dc6571e477fb2d96df02efd5fba9c54a4e998 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as uni_v3_lp_init
        , SUM(CASE WHEN t."to" = 0x93298241417a63469b6f8f080b4878749acb4c47 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0x93298241417a63469b6f8f080b4878749acb4c47 THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as rewards_wallet_init
        , SUM(CASE WHEN t."to" = 0xf8515cae6915838543bcd7756f39268ce8f853fd THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0xf8515cae6915838543bcd7756f39268ce8f853fd THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as liquidity_mining_init
        -- Track how much treasury has already sent to team wallets
        , SUM(CASE WHEN t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                    AND t."to" IN (0xaf1e1c2eb21e4b977517bc651a7046c723b49809, 0x2686b313a823f867addf697d6e67016901188076, 0xc88dff41d5e173618bba613885e9d1d062c753b7, 0xdb6ba2be3e29683ab8c9faef6a1354be8d630c2b)
               THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as treasury_to_team_init
    FROM erc20_ethereum.evt_Transfer t
    WHERE t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND t.evt_block_time < (SELECT start_date FROM dates)
      AND (
          t."to" IN (
              0x000000000000000000000000000000000000dead,
              0x19cd3998f106ecc40ee7668c19c47e18b491e8a6,
              0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49,
              0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
              0xaf1e1c2eb21e4b977517bc651a7046c723b49809,
              0x2686b313a823f867addf697d6e67016901188076,
              0xc88dff41d5e173618bba613885e9d1d062c753b7,
              0xdb6ba2be3e29683ab8c9faef6a1354be8d630c2b,
              0xed39dafd2b2a624fe43a5bbe76e0dae4e4e621ef,
              0x9ff68f61ca5eb0c6606dc517a9d44001e564bb66,
              0xd60dc6571e477fb2d96df02efd5fba9c54a4e998,
              0x93298241417a63469b6f8f080b4878749acb4c47,
              0xf8515cae6915838543bcd7756f39268ce8f853fd
          )
          OR t."from" IN (
              0x000000000000000000000000000000000000dead,
              0x19cd3998f106ecc40ee7668c19c47e18b491e8a6,
              0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49,
              0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
              0xaf1e1c2eb21e4b977517bc651a7046c723b49809,
              0x2686b313a823f867addf697d6e67016901188076,
              0xc88dff41d5e173618bba613885e9d1d062c753b7,
              0xdb6ba2be3e29683ab8c9faef6a1354be8d630c2b,
              0xed39dafd2b2a624fe43a5bbe76e0dae4e4e621ef,
              0x9ff68f61ca5eb0c6606dc517a9d44001e564bb66,
              0xd60dc6571e477fb2d96df02efd5fba9c54a4e998,
              0x93298241417a63469b6f8f080b4878749acb4c47,
              0xf8515cae6915838543bcd7756f39268ce8f853fd
          )
      )
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
        , SUM(CASE WHEN t."to" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c) THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c) THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as treasury_net
        , SUM(CASE WHEN t."to" IN (0xaf1e1c2eb21e4b977517bc651a7046c723b49809, 0x2686b313a823f867addf697d6e67016901188076, 0xc88dff41d5e173618bba613885e9d1d062c753b7, 0xdb6ba2be3e29683ab8c9faef6a1354be8d630c2b) THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" IN (0xaf1e1c2eb21e4b977517bc651a7046c723b49809, 0x2686b313a823f867addf697d6e67016901188076, 0xc88dff41d5e173618bba613885e9d1d062c753b7, 0xdb6ba2be3e29683ab8c9faef6a1354be8d630c2b) THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as team_net
        , SUM(CASE WHEN t."to" = 0xed39dafd2b2a624fe43a5bbe76e0dae4e4e621ef THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
        - SUM(CASE WHEN t."from" = 0xed39dafd2b2a624fe43a5bbe76e0dae4e4e621ef THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as airdrop_net
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
        -- Track how much treasury sent to team wallets this week
        , SUM(CASE WHEN t."from" IN (0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49, 0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c)
                    AND t."to" IN (0xaf1e1c2eb21e4b977517bc651a7046c723b49809, 0x2686b313a823f867addf697d6e67016901188076, 0xc88dff41d5e173618bba613885e9d1d062c753b7, 0xdb6ba2be3e29683ab8c9faef6a1354be8d630c2b)
               THEN CAST(t.value AS DOUBLE) / 1e18 ELSE 0 END)
          as treasury_to_team_net
    FROM erc20_ethereum.evt_Transfer t
    JOIN prices p ON t.evt_block_time >= p.week_start AND t.evt_block_time < p.week_end
    WHERE t.contract_address = 0x9dfad1b7102d46b1b197b90095b5c4e9f5845bba
      AND t.evt_block_time >= (SELECT start_date FROM dates)
      AND t.evt_block_time < (SELECT end_date FROM dates)
      AND (
          t."to" IN (
              0x000000000000000000000000000000000000dead,
              0x19cd3998f106ecc40ee7668c19c47e18b491e8a6,
              0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49,
              0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
              0xaf1e1c2eb21e4b977517bc651a7046c723b49809,
              0x2686b313a823f867addf697d6e67016901188076,
              0xc88dff41d5e173618bba613885e9d1d062c753b7,
              0xdb6ba2be3e29683ab8c9faef6a1354be8d630c2b,
              0xed39dafd2b2a624fe43a5bbe76e0dae4e4e621ef,
              0x9ff68f61ca5eb0c6606dc517a9d44001e564bb66,
              0xd60dc6571e477fb2d96df02efd5fba9c54a4e998,
              0x93298241417a63469b6f8f080b4878749acb4c47,
              0xf8515cae6915838543bcd7756f39268ce8f853fd
          )
          OR t."from" IN (
              0x000000000000000000000000000000000000dead,
              0x19cd3998f106ecc40ee7668c19c47e18b491e8a6,
              0x35bb964878d7b6ddfa69cf0b97ee63fa3c9d9b49,
              0x000a837ddd815bcba0fa91a98a50aa7a3fa62c9c,
              0xaf1e1c2eb21e4b977517bc651a7046c723b49809,
              0x2686b313a823f867addf697d6e67016901188076,
              0xc88dff41d5e173618bba613885e9d1d062c753b7,
              0xdb6ba2be3e29683ab8c9faef6a1354be8d630c2b,
              0xed39dafd2b2a624fe43a5bbe76e0dae4e4e621ef,
              0x9ff68f61ca5eb0c6606dc517a9d44001e564bb66,
              0xd60dc6571e477fb2d96df02efd5fba9c54a4e998,
              0x93298241417a63469b6f8f080b4878749acb4c47,
              0xf8515cae6915838543bcd7756f39268ce8f853fd
          )
      )
    GROUP BY p.week_end
)

, raw_balances AS (
    SELECT
          p.week_end
        , COALESCE(ib.burned_init, 0) + COALESCE(SUM(bf.burned_net) OVER (ORDER BY p.week_end ASC), 0) as burned_raw
        , COALESCE(ib.gov_staking_init, 0) + COALESCE(SUM(bf.gov_staking_net) OVER (ORDER BY p.week_end ASC), 0) as gov_staking_raw
        , COALESCE(ib.treasury_init, 0) + COALESCE(SUM(bf.treasury_net) OVER (ORDER BY p.week_end ASC), 0) as treasury_raw
        , COALESCE(ib.team_init, 0) + COALESCE(SUM(bf.team_net) OVER (ORDER BY p.week_end ASC), 0) as team_raw
        , COALESCE(ib.airdrop_init, 0) + COALESCE(SUM(bf.airdrop_net) OVER (ORDER BY p.week_end ASC), 0) as airdrop_raw
        , COALESCE(ib.uni_v2_lp_init, 0) + COALESCE(SUM(bf.uni_v2_lp_net) OVER (ORDER BY p.week_end ASC), 0) as uni_v2_lp_raw
        , COALESCE(ib.uni_v3_lp_init, 0) + COALESCE(SUM(bf.uni_v3_lp_net) OVER (ORDER BY p.week_end ASC), 0) as uni_v3_lp_raw
        , COALESCE(ib.rewards_wallet_init, 0) + COALESCE(SUM(bf.rewards_wallet_net) OVER (ORDER BY p.week_end ASC), 0) as rewards_wallet_raw
        , COALESCE(ib.liquidity_mining_init, 0) + COALESCE(SUM(bf.liquidity_mining_net) OVER (ORDER BY p.week_end ASC), 0) as liquidity_mining_raw
        -- Cumulative BOTTO sent from treasury to team (for 20M allocation adjustment)
        , COALESCE(ib.treasury_to_team_init, 0) + COALESCE(SUM(bf.treasury_to_team_net) OVER (ORDER BY p.week_end ASC), 0) as treasury_to_team_cumul
    FROM prices p
    CROSS JOIN initial_balances ib
    LEFT JOIN botto_flows bf ON bf.week_end = p.week_end
)

-- 20M team allocation: tokens held in treasury on behalf of team, distributed over ~2 years
-- team_adj = portion of 20M not yet sent from treasury to team wallets
SELECT
      week_end
    , ROUND(GREATEST(burned_raw, 0), 4) as burned
    , ROUND(GREATEST(gov_staking_raw, 0), 4) as gov_staking
    , ROUND(GREATEST(treasury_raw - GREATEST(20000000 - treasury_to_team_cumul, 0), 0), 4) as treasury
    , ROUND(GREATEST(team_raw + GREATEST(20000000 - treasury_to_team_cumul, 0), 0), 4) as team
    , ROUND(GREATEST(airdrop_raw, 0), 4) as airdrop
    , ROUND(GREATEST(uni_v2_lp_raw, 0), 4) as uni_v2_lp
    , ROUND(GREATEST(uni_v3_lp_raw, 0), 4) as uni_v3_lp
    , ROUND(GREATEST(rewards_wallet_raw, 0), 4) as rewards_wallet
    , ROUND(GREATEST(liquidity_mining_raw, 0), 4) as liquidity_mining
    , ROUND(100000000
        - GREATEST(burned_raw, 0)
        - GREATEST(gov_staking_raw, 0)
        - GREATEST(treasury_raw - GREATEST(20000000 - treasury_to_team_cumul, 0), 0)
        - GREATEST(team_raw + GREATEST(20000000 - treasury_to_team_cumul, 0), 0)
        - GREATEST(airdrop_raw, 0)
        - GREATEST(uni_v2_lp_raw, 0)
        - GREATEST(uni_v3_lp_raw, 0)
        - GREATEST(rewards_wallet_raw, 0)
        - GREATEST(liquidity_mining_raw, 0)
      , 4) as circulating
FROM raw_balances
ORDER BY week_end ASC
