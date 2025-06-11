const express = require("express");
const router = express.Router();
const {
  registerUser,
  loginUser,
  verifyCode,
  getUserProfile,
} = require("../controllers/authController");

// POST /api/auth/register - Register new user
router.post("/register", registerUser);

// POST /api/auth/login - Login existing user
router.post("/login", loginUser);

// POST /api/auth/verify - Verify code (for both register and login)
router.post("/verify", verifyCode);

// GET /api/auth/profile/:phone - Get user profile (optional)
router.get("/profile/:phone", getUserProfile);

module.exports = router;
