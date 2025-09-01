const express = require("express");
const router = express.Router();
const { authenticateToken } = require("../controllers/authController");
const {
  getUserProfile,
  getLeaderboard,
  getUserReputationDetails,
} = require("../controllers/userController");

router.get("/profile", authenticateToken, getUserProfile);
router.get("/leaderboard", getLeaderboard);
router.get("/reputation", authenticateToken, getUserReputationDetails);

module.exports = router;
