// backend/src/controllers/reportsController.js
const pool = require("../db/pool");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const {
  updateUserReputation,
  processVote,
  getUserReputationInfo,
} = require("../services/reputationService");

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadPath = "./uploads/reports/";
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(null, `report-${uniqueSuffix}${path.extname(file.originalname)}`);
  },
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|webp/;
    const extname = allowedTypes.test(
      path.extname(file.originalname).toLowerCase()
    );
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error("Only image files are allowed"));
    }
  },
});

// Submit a new report
const submitReport = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { category, description, urgencyLevel, latitude, longitude } =
      req.body;

    // Validation
    if (!category || !urgencyLevel || !latitude || !longitude) {
      return res.status(400).json({
        error: "Category, urgency level, and location are required",
      });
    }

    const validCategories = [
      "poor_lighting",
      "suspicious_gathering",
      "road_hazard",
      "violence_assault",
      "harassment",
      "police_security",
    ];
    if (!validCategories.includes(category)) {
      return res.status(400).json({ error: "Invalid category" });
    }

    const validUrgencyLevels = ["low", "medium", "high"];
    if (!validUrgencyLevels.includes(urgencyLevel.toLowerCase())) {
      return res.status(400).json({ error: "Invalid urgency level" });
    }

    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);
    if (
      isNaN(lat) ||
      isNaN(lng) ||
      lat < -90 ||
      lat > 90 ||
      lng < -180 ||
      lng > 180
    ) {
      return res.status(400).json({ error: "Invalid coordinates" });
    }

    // Check for duplicate reports
    const duplicateCheck = await pool.query(
      `SELECT id FROM reports 
       WHERE user_id = $1 AND category = $2 
       AND ST_DWithin(
         ST_MakePoint($3, $4)::geography,
         ST_MakePoint(longitude, latitude)::geography,
         100
       )
       AND created_at > NOW() - INTERVAL '1 hour'`,
      [userId, category, lng, lat]
    );

    if (duplicateCheck.rows.length > 0) {
      return res.status(409).json({
        error: "Duplicate report",
        message:
          "You have already reported this issue recently in this location",
      });
    }

    // Handle image upload
    let imagePath = null;
    if (req.file) {
      imagePath = `/uploads/reports/${req.file.filename}`;
    }

    // Insert report into database
    const result = await pool.query(
      `INSERT INTO reports 
       (user_id, category, description, urgency_level, latitude, longitude, image_path, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
       RETURNING id, category, description, urgency_level, latitude, longitude, image_path, created_at`,
      [
        userId,
        category,
        description,
        urgencyLevel.toLowerCase(),
        lat,
        lng,
        imagePath,
      ]
    );

    const report = result.rows[0];

    // Update user reputation for creating a report
    try {
      const reputationUpdate = await updateUserReputation(
        userId,
        "REPORT_CREATED",
        report.id
      );
      console.log(
        `User ${userId} gained reputation for report:`,
        reputationUpdate
      );
    } catch (repError) {
      console.error("Error updating reputation:", repError);
      // Don't fail the request if reputation update fails
    }

    // Update user's total_reports count
    await pool.query(
      "UPDATE users SET total_reports = total_reports + 1 WHERE id = $1",
      [userId]
    );

    console.log(
      `New report submitted by user ${userId}: ${category} at ${lat},${lng}`
    );

    res.status(201).json({
      success: true,
      message: "Report submitted successfully",
      report: {
        id: report.id,
        category: report.category,
        description: report.description,
        urgencyLevel: report.urgency_level,
        latitude: report.latitude,
        longitude: report.longitude,
        imagePath: report.image_path,
        createdAt: report.created_at,
        upvotes: 0,
        downvotes: 0,
        isVerified: false,
      },
    });
  } catch (err) {
    console.error("Error submitting report:", err);
    res.status(500).json({ error: "Failed to submit report" });
  }
};

// Get reports near a location
const getReportsNearby = async (req, res) => {
  try {
    const { lat, lng, radius = 1 } = req.query;

    if (!lat || !lng) {
      return res
        .status(400)
        .json({ error: "Latitude and longitude are required" });
    }

    const latitude = parseFloat(lat);
    const longitude = parseFloat(lng);
    const radiusKm = parseFloat(radius);

    if (isNaN(latitude) || isNaN(longitude) || isNaN(radiusKm)) {
      return res.status(400).json({ error: "Invalid coordinates or radius" });
    }

    // Get reports with user reputation info
    const result = await pool.query(
      `SELECT 
         r.id, r.category, r.description, r.urgency_level,
         r.latitude, r.longitude, r.image_path, r.created_at,
         r.upvotes, r.downvotes, r.is_verified,
         u.first_name, u.last_name, u.reputation_score, u.badge_level
       FROM reports r
       JOIN users u ON r.user_id = u.id
       WHERE ST_DWithin(
         ST_MakePoint($1, $2)::geography,
         ST_MakePoint(r.longitude, r.latitude)::geography,
         $3 * 1000
       )
       AND r.expires_at > NOW()
       AND r.is_active = true
       ORDER BY r.created_at DESC
       LIMIT 100`,
      [longitude, latitude, radiusKm]
    );

    const reports = result.rows.map((row) => ({
      id: row.id,
      category: row.category,
      description: row.description,
      urgencyLevel: row.urgency_level,
      latitude: parseFloat(row.latitude),
      longitude: parseFloat(row.longitude),
      imagePath: row.image_path,
      createdAt: row.created_at,
      upvotes: row.upvotes,
      downvotes: row.downvotes,
      isVerified: row.is_verified,
      reporterName: `${row.first_name} ${row.last_name.charAt(0)}.`,
      reporterReputation: row.reputation_score,
      reporterBadge: row.badge_level,
    }));

    res.status(200).json({
      success: true,
      reports: reports,
      count: reports.length,
    });
  } catch (err) {
    console.error("Error fetching nearby reports:", err);
    res.status(500).json({ error: "Failed to fetch nearby reports" });
  }
};

// Vote on a report
const voteOnReport = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { reportId } = req.params;
    const { vote } = req.body;

    if (!vote || !["up", "down"].includes(vote)) {
      return res.status(400).json({ error: "Vote must be 'up' or 'down'" });
    }

    // Check if report exists
    const reportCheck = await pool.query(
      `SELECT id, user_id FROM reports WHERE id = $1 AND is_active = true`,
      [reportId]
    );

    if (reportCheck.rows.length === 0) {
      return res.status(404).json({ error: "Report not found" });
    }

    const report = reportCheck.rows[0];

    // Users can't vote on their own reports
    if (report.user_id === userId) {
      return res.status(403).json({ error: "Cannot vote on your own report" });
    }

    // Process vote using reputation system
    const voteResult = await processVote(userId, reportId, vote);

    console.log(`User ${userId} voted ${vote} on report ${reportId}`);

    res.status(200).json({
      success: true,
      message: `Vote recorded successfully`,
      report: {
        id: reportId,
        upvotes: voteResult.upvotes,
        downvotes: voteResult.downvotes,
        weightedUpvotes: voteResult.weightedUpvotes,
        weightedDownvotes: voteResult.weightedDownvotes,
      },
      reputationUpdate: voteResult.reputationUpdate,
    });
  } catch (err) {
    console.error("Error voting on report:", err);
    res.status(500).json({ error: "Failed to record vote" });
  }
};

// Get user's reports
const getUserReports = async (req, res) => {
  try {
    const userId = req.user.userId;

    const result = await pool.query(
      `SELECT 
         id, category, description, urgency_level,
         latitude, longitude, image_path, created_at,
         upvotes, downvotes, is_verified, expires_at
       FROM reports
       WHERE user_id = $1
       ORDER BY created_at DESC`,
      [userId]
    );

    const reports = result.rows.map((row) => ({
      id: row.id,
      category: row.category,
      description: row.description,
      urgencyLevel: row.urgency_level,
      latitude: parseFloat(row.latitude),
      longitude: parseFloat(row.longitude),
      imagePath: row.image_path,
      createdAt: row.created_at,
      expiresAt: row.expires_at,
      upvotes: row.upvotes,
      downvotes: row.downvotes,
      isVerified: row.is_verified,
    }));

    res.status(200).json({
      success: true,
      reports: reports,
      count: reports.length,
    });
  } catch (err) {
    console.error("Error fetching user reports:", err);
    res.status(500).json({ error: "Failed to fetch user reports" });
  }
};

// Get user reputation info
const getReputationInfo = async (req, res) => {
  try {
    const userId = req.user.userId;

    const reputationInfo = await getUserReputationInfo(userId);

    res.status(200).json({
      success: true,
      reputation: reputationInfo,
    });
  } catch (err) {
    console.error("Error fetching user reputation:", err);
    res.status(500).json({ error: "Failed to fetch reputation info" });
  }
};

// Get report statistics
const getReportStats = async (req, res) => {
  try {
    const stats = await pool.query(`
      SELECT 
        category,
        COUNT(*) as count,
        AVG(CASE WHEN urgency_level = 'high' THEN 3 
                 WHEN urgency_level = 'medium' THEN 2 
                 ELSE 1 END) as avg_urgency,
        AVG(upvotes::float / GREATEST(upvotes + downvotes, 1)) as avg_vote_ratio
      FROM reports 
      WHERE created_at > NOW() - INTERVAL '30 days'
        AND is_active = true
      GROUP BY category
      ORDER BY count DESC
    `);

    const totalReports = await pool.query(`
      SELECT COUNT(*) as total
      FROM reports 
      WHERE created_at > NOW() - INTERVAL '30 days'
        AND is_active = true
    `);

    res.status(200).json({
      success: true,
      stats: {
        total: parseInt(totalReports.rows[0].total),
        byCategory: stats.rows.map((row) => ({
          category: row.category,
          count: parseInt(row.count),
          avgUrgency: parseFloat(row.avg_urgency).toFixed(2),
          avgVoteRatio: parseFloat(row.avg_vote_ratio).toFixed(2),
        })),
      },
    });
  } catch (err) {
    console.error("Error fetching report stats:", err);
    res.status(500).json({ error: "Failed to fetch report statistics" });
  }
};

module.exports = {
  submitReport,
  getReportsNearby,
  getUserReports,
  voteOnReport,
  getReputationInfo,
  getReportStats,
  upload,
};
