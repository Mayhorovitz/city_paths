// backend/src/controllers/userController.js
const pool = require("../db/pool");
const { getUserReputationInfo } = require("../services/reputationService");

// Get user profile with reputation info
const getUserProfile = async (req, res) => {
  try {
    const userId = req.user.userId;

    const result = await pool.query(
      `SELECT 
         u.id, u.phone, u.email, u.first_name, u.last_name, u.date_of_birth,
         u.profile_picture, u.created_at, u.last_login, u.reputation_score,
         u.badge_level, u.is_trusted_reporter, u.total_reports, u.verified_reports,
         COUNT(DISTINCT r.id) as total_user_reports,
         COUNT(DISTINCT CASE WHEN r.is_verified = true THEN r.id END) as verified_user_reports,
         AVG(r.upvotes::float / GREATEST(r.upvotes + r.downvotes, 1)) as avg_vote_ratio
       FROM users u
       LEFT JOIN reports r ON u.id = r.user_id AND r.is_active = true
       WHERE u.id = $1 AND u.is_active = true
       GROUP BY u.id`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    const user = result.rows[0];

    // Get user badges
    const badgesResult = await pool.query(
      `SELECT badge_type, badge_name, description, earned_at
       FROM user_badges 
       WHERE user_id = $1 
       ORDER BY earned_at DESC`,
      [userId]
    );

    // Get recent reputation changes
    const reputationHistoryResult = await pool.query(
      `SELECT action_type, reputation_change, reason, created_at
       FROM user_reputation_log
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 10`,
      [userId]
    );

    res.status(200).json({
      success: true,
      user: {
        id: user.id,
        phone: user.phone,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        dateOfBirth: user.date_of_birth,
        profilePicture: user.profile_picture,
        createdAt: user.created_at,
        lastLogin: user.last_login,
        reputation: {
          score: user.reputation_score,
          badgeLevel: user.badge_level,
          isTrustedReporter: user.is_trusted_reporter,
          totalReports: parseInt(user.total_user_reports) || 0,
          verifiedReports: parseInt(user.verified_user_reports) || 0,
          avgVoteRatio: user.avg_vote_ratio
            ? parseFloat(user.avg_vote_ratio).toFixed(2)
            : "0.00",
        },
        badges: badgesResult.rows,
        recentActivity: reputationHistoryResult.rows,
      },
    });
  } catch (err) {
    console.error("Error fetching user profile:", err);
    res.status(500).json({ error: "Error fetching user profile" });
  }
};

// Get leaderboard of top users
const getLeaderboard = async (req, res) => {
  try {
    const { limit = 20 } = req.query;

    const result = await pool.query(
      `SELECT 
         u.first_name, u.last_name, u.reputation_score, u.badge_level,
         u.total_reports, u.verified_reports, u.created_at,
         COUNT(DISTINCT r.id) as active_reports,
         AVG(r.upvotes::float / GREATEST(r.upvotes + r.downvotes, 1)) as avg_vote_ratio
       FROM users u
       LEFT JOIN reports r ON u.id = r.user_id AND r.is_active = true
       WHERE u.is_active = true AND u.total_reports > 0
       GROUP BY u.id
       ORDER BY u.reputation_score DESC, u.verified_reports DESC
       LIMIT $1`,
      [parseInt(limit)]
    );

    const leaderboard = result.rows.map((row, index) => ({
      rank: index + 1,
      name: `${row.first_name} ${row.last_name.charAt(0)}.`,
      reputationScore: row.reputation_score,
      badgeLevel: row.badge_level,
      totalReports: row.total_reports || 0,
      verifiedReports: row.verified_reports || 0,
      avgVoteRatio: row.avg_vote_ratio
        ? parseFloat(row.avg_vote_ratio).toFixed(2)
        : "0.00",
      memberSince: row.created_at,
    }));

    res.status(200).json({
      success: true,
      leaderboard: leaderboard,
      count: leaderboard.length,
    });
  } catch (err) {
    console.error("Error fetching leaderboard:", err);
    res.status(500).json({ error: "Error fetching leaderboard" });
  }
};

// Get user reputation details
const getUserReputationDetails = async (req, res) => {
  try {
    const userId = req.user.userId;

    // Get detailed reputation breakdown
    const reputationBreakdown = await pool.query(
      `SELECT 
         action_type,
         COUNT(*) as count,
         SUM(reputation_change) as total_points
       FROM user_reputation_log
       WHERE user_id = $1
       GROUP BY action_type
       ORDER BY total_points DESC`,
      [userId]
    );

    // Get monthly reputation trend
    const monthlyTrend = await pool.query(
      `SELECT 
         DATE_TRUNC('month', created_at) as month,
         SUM(reputation_change) as points_gained,
         COUNT(*) as actions
       FROM user_reputation_log
       WHERE user_id = $1 
         AND created_at > NOW() - INTERVAL '6 months'
       GROUP BY DATE_TRUNC('month', created_at)
       ORDER BY month DESC`,
      [userId]
    );

    // Calculate next badge requirements
    const currentUser = await pool.query(
      "SELECT reputation_score, badge_level FROM users WHERE id = $1",
      [userId]
    );

    const currentScore = currentUser.rows[0]?.reputation_score || 0;
    const currentBadge = currentUser.rows[0]?.badge_level || "newcomer";

    let nextBadge = null;
    let pointsToNext = 0;

    const badgeThresholds = {
      newcomer: { next: "regular", threshold: 26 },
      regular: { next: "trusted", threshold: 51 },
      trusted: { next: "expert", threshold: 76 },
      expert: { next: null, threshold: 100 },
    };

    if (badgeThresholds[currentBadge]?.next) {
      nextBadge = badgeThresholds[currentBadge].next;
      pointsToNext = badgeThresholds[currentBadge].threshold - currentScore;
    }

    res.status(200).json({
      success: true,
      reputationDetails: {
        currentScore: currentScore,
        currentBadge: currentBadge,
        nextBadge: nextBadge,
        pointsToNext: Math.max(0, pointsToNext),
        breakdown: reputationBreakdown.rows,
        monthlyTrend: monthlyTrend.rows,
        badgeThresholds: badgeThresholds,
      },
    });
  } catch (err) {
    console.error("Error fetching reputation details:", err);
    res.status(500).json({ error: "Error fetching reputation details" });
  }
};

module.exports = {
  getUserProfile,
  getLeaderboard,
  getUserReputationDetails,
};
