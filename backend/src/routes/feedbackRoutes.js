// backend/src/routes/feedbackRoutes.js
const express = require("express");
const router = express.Router();
const {
  submitRouteFeedback,
  getMLTrainingData,
  getFeedbackAnalytics,
} = require("../controllers/feedbackController");
const { authenticateToken } = require("../controllers/authController");

// Protected routes
router.post("/submit", authenticateToken, submitRouteFeedback);
router.get("/analytics", authenticateToken, getFeedbackAnalytics);

// Admin routes (you might want to add admin authentication later)
router.get("/ml-data", getMLTrainingData);

module.exports = router;
