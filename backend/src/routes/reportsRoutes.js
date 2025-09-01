const express = require("express");
const router = express.Router();
const {
  submitReport,
  getReportsNearby,
  getUserReports,
  voteOnReport,
  getReportStats,
  upload,
} = require("../controllers/reportsController");
const { authenticateToken } = require("../controllers/authController");

// Protected routes
router.post("/submit", authenticateToken, upload.single("image"), submitReport);
router.get("/my-reports", authenticateToken, getUserReports);
router.post("/:reportId/vote", authenticateToken, voteOnReport);
router.get("/reputation", authenticateToken, getUserReputationInfo);

// Public routes
router.get("/nearby", getReportsNearby);
router.get("/stats", getReportStats);

module.exports = router;
