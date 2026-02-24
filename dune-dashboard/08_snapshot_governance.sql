-- ============================================================
-- BOTTO DASHBOARD: Snapshot Governance Activity
-- ============================================================
-- Charts:
--   1. Table: per-proposal details
--   2. Bar chart: monthly_proposal_count, monthly_avg_voters
--      by proposal_month
-- ============================================================

WITH proposals AS (
    SELECT
          id as proposal_id
        , title
        , from_unixtime(start) as start_time
        , from_unixtime("end") as end_time
        , scores_total as total_voting_power
        , element_at(scores, 1) as for_power
    FROM snapshot.proposals
    WHERE space = 'botto.eth'
)

, vote_counts AS (
    SELECT
          v.proposal_id
        , COUNT(DISTINCT v.voter) as voter_count
    FROM snapshot.votes v
    JOIN proposals p ON p.proposal_id = v.proposal_id
    GROUP BY v.proposal_id
)

, proposal_detail AS (
    SELECT
          p.proposal_id
        , p.title
        , CAST(p.start_time AS DATE) as proposal_date
        , DATE_TRUNC('month', p.start_time) as proposal_month
        , COALESCE(vc.voter_count, 0) as voter_count
        , ROUND(p.total_voting_power, 2) as total_voting_power
        , ROUND(COALESCE(p.for_power, 0), 2) as for_power
        , CASE
            WHEN p.total_voting_power > 0
            THEN ROUND(COALESCE(p.for_power, 0) / p.total_voting_power * 100, 2)
            ELSE 0
          END as approval_pct
        , CASE WHEN p.total_voting_power >= 500000 THEN 'Yes' ELSE 'No' END as quorum_met
        , CASE
            WHEN p.total_voting_power >= 500000
                 AND COALESCE(p.for_power, 0) / NULLIF(p.total_voting_power, 0) * 100 >= 66.66
            THEN 'Passed'
            ELSE 'Failed'
          END as result
    FROM proposals p
    LEFT JOIN vote_counts vc ON vc.proposal_id = p.proposal_id
)

SELECT
      proposal_date
    , title
    , voter_count
    , total_voting_power
    , for_power
    , approval_pct
    , quorum_met
    , result
    , proposal_month
    , COUNT(*) OVER (PARTITION BY proposal_month) as monthly_proposal_count
    , ROUND(AVG(voter_count) OVER (PARTITION BY proposal_month), 1) as monthly_avg_voters
    , ROUND(
        SUM(CASE WHEN quorum_met = 'Yes' THEN 1 ELSE 0 END) OVER (PARTITION BY proposal_month)
        * 100.0 / COUNT(*) OVER (PARTITION BY proposal_month), 1
      ) as monthly_quorum_achievement_pct
FROM proposal_detail
ORDER BY proposal_date DESC
