// backend/src/controllers/feedbackController.js
const pool = require("../db/pool");

const submitRouteFeedback = async (req, res) => {
  const userId = req.user.userId;
  const {
    routeData,
    safetyRating,
    accuracyRating,
    wouldUseAgain,
    comments,
    actualDuration,
    encounteredReports,
  } = req.body;

  // Validation
  if (!routeData || !safetyRating || !accuracyRating) {
    return res.status(400).json({
      error: "Route data, safety rating, and accuracy rating are required",
    });
  }

  if (
    safetyRating < 1 ||
    safetyRating > 5 ||
    accuracyRating < 1 ||
    accuracyRating > 5
  ) {
    return res.status(400).json({
      error: "Ratings must be between 1 and 5",
    });
  }

  try {
    // Extract features from route data for ML training
    const features = {
      // Route characteristics
      predictedSafetyScore: routeData.score || 0,
      lightingScore: routeData.lightingScore || 0,
      businessScore: routeData.businessScore || 0,
      crimeScore: routeData.crimeScore || 0,
      reportsScore: routeData.reportsScore || 0,

      // Route metadata
      routeLength: routeData.distance?.kilometers || 0,
      estimatedDuration: routeData.walkingTime?.minutes || 0,
      actualDuration: actualDuration || 0,

      // Context features
      timeOfDay: new Date().getHours(),
      dayOfWeek: new Date().getDay(),
      month: new Date().getMonth() + 1,
      season: Math.floor((new Date().getMonth() + 1) / 3),

      // Dynamic features
      encounteredReportsCount: encounteredReports?.length || 0,
      encounteredReportsTypes: encounteredReports?.map((r) => r.category) || [],
    };

    // Insert into route_feedback table
    const feedbackResult = await pool.query(
      `INSERT INTO route_feedback (
         user_id, route_data, safety_rating, accuracy_rating, 
         would_use_again, comments, features, created_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
       RETURNING id`,
      [
        userId,
        JSON.stringify(routeData),
        safetyRating,
        accuracyRating,
        wouldUseAgain,
        comments,
        JSON.stringify(features),
      ]
    );

    const feedbackId = feedbackResult.rows[0].id;

    // Insert training data for ML model
    await pool.query(
      `INSERT INTO ml_training_data (
         feedback_id, user_id,
         predicted_safety_score, actual_safety_rating,
         lighting_score, business_score, crime_score, reports_score,
         route_length_km, estimated_duration_min, actual_duration_min,
         time_of_day, day_of_week, month, season,
         encountered_reports_count, encountered_reports_types,
         accuracy_rating, would_use_again,
         created_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, NOW())`,
      [
        feedbackId,
        userId,
        features.predictedSafetyScore,
        safetyRating,
        features.lightingScore,
        features.businessScore,
        features.crimeScore,
        features.reportsScore,
        features.routeLength,
        features.estimatedDuration,
        features.actualDuration,
        features.timeOfDay,
        features.dayOfWeek,
        features.month,
        features.season,
        features.encounteredReportsCount,
        JSON.stringify(features.encounteredReportsTypes),
        accuracyRating,
        wouldUseAgain,
      ]
    );

    // Update user reputation for providing feedback
    await pool.query(
      "UPDATE users SET total_feedback = COALESCE(total_feedback, 0) + 1 WHERE id = $1",
      [userId]
    );

    res.status(201).json({
      success: true,
      message: "Feedback submitted successfully",
      feedbackId: feedbackId,
    });
  } catch (err) {
    console.error("Error submitting feedback:", err);
    res.status(500).json({ error: "Failed to submit feedback" });
  }
};

// Get ML training data export (for data scientists)
const getMLTrainingData = async (req, res) => {
  const { limit = 1000, offset = 0, format = "json" } = req.query;

  try {
    const result = await pool.query(
      `SELECT 
         mtd.*,
         u.reputation_score,
         u.badge_level,
         EXTRACT(EPOCH FROM (mtd.created_at - u.created_at)) / 86400 as user_age_days
       FROM ml_training_data mtd
       JOIN users u ON mtd.user_id = u.id
       ORDER BY mtd.created_at DESC
       LIMIT $1 OFFSET $2`,
      [parseInt(limit), parseInt(offset)]
    );

    if (format === "csv") {
      // Convert to CSV format for easy ML processing
      const headers = Object.keys(result.rows[0] || {});
      const csvData = [
        headers.join(","),
        ...result.rows.map((row) =>
          headers
            .map((header) =>
              typeof row[header] === "object"
                ? JSON.stringify(row[header])
                : row[header]
            )
            .join(",")
        ),
      ].join("\n");

      res.setHeader("Content-Type", "text/csv");
      res.setHeader(
        "Content-Disposition",
        'attachment; filename="ml_training_data.csv"'
      );
      res.send(csvData);
    } else {
      res.json({
        success: true,
        data: result.rows,
        count: result.rows.length,
        pagination: {
          limit: parseInt(limit),
          offset: parseInt(offset),
        },
      });
    }
  } catch (err) {
    console.error("Error exporting ML data:", err);
    res.status(500).json({ error: "Failed to export training data" });
  }
};

// Get feedback analytics
const getFeedbackAnalytics = async (req, res) => {
  try {
    // Overall stats
    const overallStats = await pool.query(`
      SELECT 
        COUNT(*) as total_feedback,
        AVG(safety_rating)::numeric(3,2) as avg_safety_rating,
        AVG(accuracy_rating)::numeric(3,2) as avg_accuracy_rating,
        AVG(CASE WHEN would_use_again THEN 1 ELSE 0 END)::numeric(3,2) as would_use_again_rate
      FROM route_feedback
      WHERE created_at > NOW() - INTERVAL '30 days'
    `);

    // Accuracy analysis
    const accuracyAnalysis = await pool.query(`
      SELECT 
        CASE 
          WHEN predicted_safety_score >= 80 THEN 'high'
          WHEN predicted_safety_score >= 60 THEN 'medium' 
          ELSE 'low'
        END as predicted_category,
        AVG(actual_safety_rating) as avg_actual_rating,
        AVG(accuracy_rating) as avg_accuracy_rating,
        COUNT(*) as sample_count
      FROM ml_training_data
      WHERE created_at > NOW() - INTERVAL '30 days'
      GROUP BY 1
      ORDER BY predicted_category
    `);

    // Time-based patterns
    const timePatterns = await pool.query(`
      SELECT 
        time_of_day,
        AVG(actual_safety_rating) as avg_safety_rating,
        COUNT(*) as sample_count
      FROM ml_training_data
      WHERE created_at > NOW() - INTERVAL '30 days'
      GROUP BY time_of_day
      ORDER BY time_of_day
    `);

    res.json({
      success: true,
      analytics: {
        overall: overallStats.rows[0],
        accuracy: accuracyAnalysis.rows,
        timePatterns: timePatterns.rows,
      },
    });
  } catch (err) {
    console.error("Error fetching analytics:", err);
    res.status(500).json({ error: "Failed to fetch analytics" });
  }
};

module.exports = {
  submitRouteFeedback,
  getMLTrainingData,
  getFeedbackAnalytics,
};
