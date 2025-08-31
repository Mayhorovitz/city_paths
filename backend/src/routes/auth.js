const express = require("express");
const router = express.Router();
const {
  registerUser,
  loginUser,
  getUserProfile,
  updateUserProfile,
  changePassword,
  authenticateToken,
} = require("../controllers/authController");

// Public routes
router.post("/register", registerUser);
router.post("/login", loginUser);

// Protected routes
router.get("/profile", authenticateToken, getUserProfile);
router.put("/profile", authenticateToken, updateUserProfile);
router.put("/change-password", authenticateToken, changePassword);

module.exports = router;
