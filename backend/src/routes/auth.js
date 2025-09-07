const express = require("express");
const router = express.Router();
const {
  registerUser,
  loginUser,
  getUserProfile,
  updateUserProfile,
  updateUserPreferences,
  getPreferencePresets,
  changePassword,
  authenticateToken,
} = require("../controllers/authController");

// Public routes
router.post("/register", registerUser);
router.post("/login", loginUser);
router.get("/presets", getPreferencePresets); // Get available preference presets

// Protected routes
router.get("/profile", authenticateToken, getUserProfile);
router.put("/profile", authenticateToken, updateUserProfile);
router.put("/preferences", authenticateToken, updateUserPreferences); // New route for preferences
router.put("/change-password", authenticateToken, changePassword);

module.exports = router;
