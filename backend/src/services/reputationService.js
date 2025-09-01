// backend/src/services/reputationService.js
const pool = require("../db/pool");

// Reputation constants
const REPUTATION_ACTIONS = {
  REPORT_CREATED: { points: 2, reason: "Created a report" },
  VOTE_RECEIVED_UP: { points: 3, reason: "Received upvote on report" },
  VOTE_RECEIVED_DOWN: { points: -1, reason: "Received downvote on report" },
  REPORT_VERIFIED: { points: 10, reason: "Report verified by community" },
  REPORT_FLAGGED_SPAM: { points: -15, reason: "Report flagged as spam" },
  HELPFUL_VOTE_GIVEN: { points: 1, reason: "Gave helpful vote" },
};

// Badge levels
const BADGE_LEVELS = {
  newcomer: { min: 0, max: 25, voteWeight: 0.5 },
  regular: { min: 26, max: 50, voteWeight: 1.0 },
  trusted: { min: 51, max: 75, voteWeight: 1.5 },
  expert: { min: 76, max: 100, voteWeight: 2.0 },
};

// Calculate user's reputation and update badge
async function updateUserReputation(
  userId,
  actionType,
  relatedReportId = null
) {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // Get current user reputation
    const userResult = await client.query(
      "SELECT reputation_score, badge_level FROM users WHERE id = $1",
      [userId]
    );

    if (userResult.rows.length === 0) {
      throw new Error("User not found");
    }

    const currentReputation = userResult.rows[0].reputation_score;
    const reputationChange = REPUTATION_ACTIONS[actionType].points;
    const newReputation = Math.max(
      0,
      Math.min(100, currentReputation + reputationChange)
    );

    // Update user reputation
    await client.query("UPDATE users SET reputation_score = $1 WHERE id = $2", [
      newReputation,
      userId,
    ]);

    // Log the reputation change
    await client.query(
      `INSERT INTO user_reputation_log (user_id, action_type, reputation_change, reason, related_report_id)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        userId,
        actionType,
        reputationChange,
        REPUTATION_ACTIONS[actionType].reason,
        relatedReportId,
      ]
    );

    // Check if badge level changed
    const newBadgeLevel = getBadgeLevel(newReputation);
    const currentBadgeLevel = userResult.rows[0].badge_level;

    if (newBadgeLevel !== currentBadgeLevel) {
      await updateUserBadge(client, userId, newBadgeLevel);
    }

    await client.query("COMMIT");

    console.log(
      `User ${userId} reputation updated: ${currentReputation} → ${newReputation} (${actionType})`
    );

    return {
      userId,
      oldReputation: currentReputation,
      newReputation,
      badgeLevel: newBadgeLevel,
      reputationChange,
    };
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Error updating user reputation:", error);
    throw error;
  } finally {
    client.release();
  }
}

// Get badge level based on reputation score
function getBadgeLevel(reputation) {
  for (const [level, config] of Object.entries(BADGE_LEVELS)) {
    if (reputation >= config.min && reputation <= config.max) {
      return level;
    }
  }
  return "newcomer";
}

// Update user badge and create badge record
async function updateUserBadge(client, userId, badgeLevel) {
  // Update user badge
  await client.query(
    "UPDATE users SET badge_level = $1, is_trusted_reporter = $2 WHERE id = $3",
    [badgeLevel, badgeLevel === "trusted" || badgeLevel === "expert", userId]
  );

  // Add badge to user_badges table
  const badgeNames = {
    newcomer: "New Reporter",
    regular: "Regular Reporter",
    trusted: "Trusted Reporter",
    expert: "Expert Reporter",
  };

  const badgeDescriptions = {
    newcomer: "Welcome to City Path! Keep reporting to build your reputation.",
    regular:
      "You're getting the hang of it! Your reports are valued by the community.",
    trusted:
      "Your reports are highly valued. You have a stronger voice in voting.",
    expert: "You're a safety expert! Your votes carry significant weight.",
  };

  await client.query(
    `INSERT INTO user_badges (user_id, badge_type, badge_name, description)
     VALUES ($1, $2, $3, $4)`,
    [userId, badgeLevel, badgeNames[badgeLevel], badgeDescriptions[badgeLevel]]
  );
}

// Get vote weight based on user's reputation
function getVoteWeight(reputation) {
  const badgeLevel = getBadgeLevel(reputation);
  return BADGE_LEVELS[badgeLevel].voteWeight;
}

// Process vote and update reputations
async function processVote(voterId, reportId, voteType) {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // Get voter's current reputation for vote weighting
    const voterResult = await client.query(
      "SELECT reputation_score FROM users WHERE id = $1",
      [voterId]
    );

    if (voterResult.rows.length === 0) {
      throw new Error("Voter not found");
    }

    const voterReputation = voterResult.rows[0].reputation_score;
    const voteWeight = getVoteWeight(voterReputation);

    // Get report owner
    const reportResult = await client.query(
      "SELECT user_id FROM reports WHERE id = $1",
      [reportId]
    );

    if (reportResult.rows.length === 0) {
      throw new Error("Report not found");
    }

    const reportOwnerId = reportResult.rows[0].user_id;

    // Check if vote already exists
    const existingVoteResult = await client.query(
      "SELECT vote_type FROM report_votes WHERE report_id = $1 AND user_id = $2",
      [reportId, voterId]
    );

    let reputationUpdate = null;

    if (existingVoteResult.rows.length > 0) {
      // Update existing vote
      const oldVoteType = existingVoteResult.rows[0].vote_type;

      if (oldVoteType !== voteType) {
        await client.query(
          `UPDATE report_votes 
           SET vote_type = $1, voter_reputation_at_time = $2, vote_weight = $3, updated_at = NOW()
           WHERE report_id = $4 AND user_id = $5`,
          [voteType, voterReputation, voteWeight, reportId, voterId]
        );

        // Update report owner reputation
        if (oldVoteType === "up" && voteType === "down") {
          // Changed from upvote to downvote
          await updateUserReputation(
            reportOwnerId,
            "VOTE_RECEIVED_DOWN",
            reportId
          );
          await updateUserReputation(
            reportOwnerId,
            "VOTE_RECEIVED_DOWN",
            reportId
          ); // -3 for losing upvote, -1 for downvote
        } else if (oldVoteType === "down" && voteType === "up") {
          // Changed from downvote to upvote
          await updateUserReputation(
            reportOwnerId,
            "VOTE_RECEIVED_UP",
            reportId
          );
          await updateUserReputation(
            reportOwnerId,
            "VOTE_RECEIVED_UP",
            reportId
          ); // +1 for losing downvote, +3 for upvote
        }
      }
    } else {
      // Insert new vote
      await client.query(
        `INSERT INTO report_votes (report_id, user_id, vote_type, voter_reputation_at_time, vote_weight)
         VALUES ($1, $2, $3, $4, $5)`,
        [reportId, voterId, voteType, voterReputation, voteWeight]
      );

      // Update report owner reputation
      const actionType =
        voteType === "up" ? "VOTE_RECEIVED_UP" : "VOTE_RECEIVED_DOWN";
      reputationUpdate = await updateUserReputation(
        reportOwnerId,
        actionType,
        reportId
      );

      // Give small reputation bonus to voter for participating
      await updateUserReputation(voterId, "HELPFUL_VOTE_GIVEN", reportId);
    }

    // Update vote counts in reports table with weighted votes
    const voteCountsResult = await client.query(
      `SELECT 
         COALESCE(SUM(CASE WHEN vote_type = 'up' THEN vote_weight END), 0) as weighted_upvotes,
         COALESCE(SUM(CASE WHEN vote_type = 'down' THEN vote_weight END), 0) as weighted_downvotes,
         COUNT(CASE WHEN vote_type = 'up' THEN 1 END) as upvotes,
         COUNT(CASE WHEN vote_type = 'down' THEN 1 END) as downvotes
       FROM report_votes 
       WHERE report_id = $1`,
      [reportId]
    );

    const { upvotes, downvotes, weighted_upvotes, weighted_downvotes } =
      voteCountsResult.rows[0];

    await client.query(
      "UPDATE reports SET upvotes = $1, downvotes = $2 WHERE id = $3",
      [parseInt(upvotes), parseInt(downvotes), reportId]
    );

    // Check if report should be verified or flagged
    const totalVotes = parseInt(upvotes) + parseInt(downvotes);
    if (totalVotes >= 5) {
      const weightedTotal =
        parseFloat(weighted_upvotes) + parseFloat(weighted_downvotes);
      const positiveRatio = parseFloat(weighted_upvotes) / weightedTotal;

      if (positiveRatio >= 0.7) {
        // Verify report and bonus reputation
        await client.query(
          "UPDATE reports SET is_verified = true WHERE id = $1",
          [reportId]
        );
        await updateUserReputation(reportOwnerId, "REPORT_VERIFIED", reportId);
      } else if (positiveRatio <= 0.3) {
        // Flag as spam and penalty
        await client.query(
          "UPDATE reports SET is_active = false WHERE id = $1",
          [reportId]
        );
        await updateUserReputation(
          reportOwnerId,
          "REPORT_FLAGGED_SPAM",
          reportId
        );
      }
    }

    await client.query("COMMIT");

    return {
      success: true,
      upvotes: parseInt(upvotes),
      downvotes: parseInt(downvotes),
      weightedUpvotes: parseFloat(weighted_upvotes),
      weightedDownvotes: parseFloat(weighted_downvotes),
      reputationUpdate,
    };
  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Error processing vote:", error);
    throw error;
  } finally {
    client.release();
  }
}

// Get user reputation info
async function getUserReputationInfo(userId) {
  try {
    const result = await pool.query(
      `SELECT 
         u.reputation_score,
         u.badge_level,
         u.is_trusted_reporter,
         u.total_reports,
         u.verified_reports,
         COUNT(ub.id) as badge_count,
         ARRAY_AGG(
           json_build_object(
             'badge_name', ub.badge_name,
             'description', ub.description,
             'earned_at', ub.earned_at
           ) ORDER BY ub.earned_at DESC
         ) FILTER (WHERE ub.id IS NOT NULL) as badges
       FROM users u
       LEFT JOIN user_badges ub ON u.id = ub.user_id
       WHERE u.id = $1
       GROUP BY u.id`,
      [userId]
    );

    if (result.rows.length === 0) {
      throw new Error("User not found");
    }

    return result.rows[0];
  } catch (error) {
    console.error("Error getting user reputation info:", error);
    throw error;
  }
}

module.exports = {
  updateUserReputation,
  processVote,
  getUserReputationInfo,
  getVoteWeight,
  getBadgeLevel,
  BADGE_LEVELS,
  REPUTATION_ACTIONS,
};
