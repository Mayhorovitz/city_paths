const pool = require("../db/pool");
const multer = require("multer");
const path = require("path");
const fs = require("fs");

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
  limits: {
    fileSize: 5 * 1024 * 1024,
  },
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

    // Validate category
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

    // Validate urgency level
    const validUrgencyLevels = ["low", "medium", "high"];
    if (!validUrgencyLevels.includes(urgencyLevel.toLowerCase())) {
      return res.status(400).json({ error: "Invalid urgency level" });
    }

    // Validate coordinates
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

    // Get reports within radius
    const result = await pool.query(
      `SELECT 
         r.id, r.category, r.description, r.urgency_level,
         r.latitude, r.longitude, r.image_path, r.created_at,
         r.upvotes, r.downvotes, r.is_verified,
         u.first_name, u.last_name
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

// Vote on a report (for verification)
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
      `SELECT id, user_id, upvotes, downvotes FROM reports WHERE id = $1 AND is_active = true`,
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

    // Check if user already voted
    const existingVote = await pool.query(
      `SELECT vote_type FROM report_votes WHERE report_id = $1 AND user_id = $2`,
      [reportId, userId]
    );

    let updateQuery;
    let updateParams;

    if (existingVote.rows.length > 0) {
      // Update existing vote
      const oldVote = existingVote.rows[0].vote_type;

      if (oldVote === vote) {
        return res
          .status(400)
          .json({ error: "You have already voted this way" });
      }

      // Update the vote
      await pool.query(
        `UPDATE report_votes SET vote_type = $1, updated_at = NOW() 
         WHERE report_id = $2 AND user_id = $3`,
        [vote, reportId, userId]
      );

      // Update report counters
      if (oldVote === "up" && vote === "down") {
        updateQuery = `UPDATE reports SET upvotes = upvotes - 1, downvotes = downvotes + 1 WHERE id = $1 RETURNING upvotes, downvotes`;
      } else if (oldVote === "down" && vote === "up") {
        updateQuery = `UPDATE reports SET upvotes = upvotes + 1, downvotes = downvotes - 1 WHERE id = $1 RETURNING upvotes, downvotes`;
      }
      updateParams = [reportId];
    } else {
      // Insert new vote
      await pool.query(
        `INSERT INTO report_votes (report_id, user_id, vote_type, created_at)
         VALUES ($1, $2, $3, NOW())`,
        [reportId, userId, vote]
      );

      // Update report counters
      if (vote === "up") {
        updateQuery = `UPDATE reports SET upvotes = upvotes + 1 WHERE id = $1 RETURNING upvotes, downvotes`;
      } else {
        updateQuery = `UPDATE reports SET downvotes = downvotes + 1 WHERE id = $1 RETURNING upvotes, downvotes`;
      }
      updateParams = [reportId];
    }

    const updateResult = await pool.query(updateQuery, updateParams);
    const updatedReport = updateResult.rows[0];

    // Check if report should be verified or flagged
    const totalVotes = updatedReport.upvotes + updatedReport.downvotes;
    if (totalVotes >= 5) {
      const ratio = updatedReport.upvotes / totalVotes;
      let verificationUpdate = "";

      if (ratio >= 0.7) {
        // 70% upvotes = verified
        verificationUpdate = "is_verified = true";
      } else if (ratio <= 0.3) {
        // 30% or less upvotes = flag as questionable
        verificationUpdate = "is_active = false";
      }

      if (verificationUpdate) {
        await pool.query(
          `UPDATE reports SET ${verificationUpdate} WHERE id = $1`,
          [reportId]
        );
      }
    }

    console.log(`User ${userId} voted ${vote} on report ${reportId}`);

    res.status(200).json({
      success: true,
      message: `Vote recorded successfully`,
      report: {
        id: reportId,
        upvotes: updatedReport.upvotes,
        downvotes: updatedReport.downvotes,
      },
    });
  } catch (err) {
    console.error("Error voting on report:", err);
    res.status(500).json({ error: "Failed to record vote" });
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
                 ELSE 1 END) as avg_urgency
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
  getReportStats,
  upload,
};
