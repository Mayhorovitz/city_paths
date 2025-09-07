const pool = require("../db/pool");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

const JWT_SECRET = process.env.JWT_SECRET;
const SALT_ROUNDS = 12;

// Register new user
const registerUser = async (req, res) => {
  const {
    phone,
    email,
    password,
    firstName,
    lastName,
    dateOfBirth,
    lightingPreference = 0.3,
    businessPreference = 0.25,
    crimePreference = 0.2,
    reportsPreference = 0.25,
  } = req.body;

  // Validation
  if (!phone || !email || !password || !firstName || !lastName) {
    return res.status(400).json({
      error: "Phone, email, password, first name, and last name are required",
    });
  }

  if (password.length < 6) {
    return res.status(400).json({
      error: "Password must be at least 6 characters long",
    });
  }

  if (!isValidEmail(email)) {
    return res.status(400).json({
      error: "Please provide a valid email address",
    });
  }

  if (!isValidPhone(phone)) {
    return res.status(400).json({
      error: "Please provide a valid phone number",
    });
  }

  // Validate preferences
  const totalPreferences =
    lightingPreference +
    businessPreference +
    crimePreference +
    reportsPreference;
  if (Math.abs(totalPreferences - 1.0) > 0.01) {
    return res.status(400).json({
      error: "Safety preferences must sum to 1.0",
    });
  }

  // Validate each preference is between 0 and 1
  if (
    [
      lightingPreference,
      businessPreference,
      crimePreference,
      reportsPreference,
    ].some((pref) => pref < 0 || pref > 1)
  ) {
    return res.status(400).json({
      error: "Each preference must be between 0 and 1",
    });
  }

  try {
    // Check if user already exists
    const existingUser = await pool.query(
      `SELECT id, phone, email FROM users WHERE phone = $1 OR email = $2`,
      [phone, email]
    );

    if (existingUser.rows.length > 0) {
      const existing = existingUser.rows[0];
      if (existing.phone === phone) {
        return res.status(409).json({
          error: "Phone number already registered",
          message:
            "This phone number is already in use. Please use a different number or login.",
        });
      }
      if (existing.email === email) {
        return res.status(409).json({
          error: "Email already registered",
          message:
            "This email is already in use. Please use a different email or login.",
        });
      }
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    // Insert new user with preferences
    const result = await pool.query(
      `
        INSERT INTO users (phone, email, password_hash, first_name, last_name, date_of_birth, 
                          lighting_preference, business_preference, crime_preference, reports_preference,
                          verified, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, true, NOW())
        RETURNING id, phone, email, first_name, last_name, 
                  lighting_preference, business_preference, crime_preference, reports_preference, created_at
        `,
      [
        phone,
        email,
        passwordHash,
        firstName,
        lastName,
        dateOfBirth || null,
        lightingPreference,
        businessPreference,
        crimePreference,
        reportsPreference,
      ]
    );

    const newUser = result.rows[0];

    // Generate JWT token
    const token = jwt.sign(
      {
        userId: newUser.id,
        phone: newUser.phone,
        email: newUser.email,
      },
      JWT_SECRET,
      { expiresIn: "7d" }
    );

    console.log(
      `New user registered: ${newUser.first_name} ${newUser.last_name} (${newUser.phone}) with custom preferences`
    );

    res.status(201).json({
      success: true,
      message: "Registration successful!",
      token,
      user: {
        id: newUser.id,
        phone: newUser.phone,
        email: newUser.email,
        firstName: newUser.first_name,
        lastName: newUser.last_name,
        createdAt: newUser.created_at,
        preferences: {
          lighting: newUser.lighting_preference,
          business: newUser.business_preference,
          crime: newUser.crime_preference,
          reports: newUser.reports_preference,
        },
      },
    });
  } catch (err) {
    console.error("Error during registration:", err);

    if (err.code === "23505") {
      return res.status(409).json({
        error: "User already exists",
        message: "This phone number or email is already registered.",
      });
    }

    if (err.code === "23514") {
      // Constraint violation
      return res.status(400).json({
        error: "Invalid preferences",
        message: "Safety preferences must sum to 1.0.",
      });
    }

    res.status(500).json({ error: "Registration failed. Please try again." });
  }
};

// Login user
const loginUser = async (req, res) => {
  const { phoneOrEmail, password } = req.body;

  if (!phoneOrEmail || !password) {
    return res.status(400).json({
      error: "Phone/email and password are required",
    });
  }

  try {
    // Find user by phone or email - include preferences
    const result = await pool.query(
      `SELECT id, phone, email, password_hash, first_name, last_name, 
              is_active, failed_login_attempts, locked_until,
              lighting_preference, business_preference, crime_preference, reports_preference
       FROM users 
       WHERE phone = $1 OR email = $1`,
      [phoneOrEmail]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        error: "Invalid credentials",
        message: "Phone/email or password is incorrect.",
      });
    }

    const user = result.rows[0];

    // Check if account is locked
    if (user.locked_until && new Date() < new Date(user.locked_until)) {
      const remainingTime = Math.ceil(
        (new Date(user.locked_until) - new Date()) / 1000 / 60
      );
      return res.status(423).json({
        error: "Account temporarily locked",
        message: `Account is locked due to multiple failed login attempts. Try again in ${remainingTime} minutes.`,
      });
    }

    // Check if account is active
    if (!user.is_active) {
      return res.status(403).json({
        error: "Account disabled",
        message: "Your account has been disabled. Please contact support.",
      });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);

    if (!isValidPassword) {
      // Increment failed login attempts
      const failedAttempts = user.failed_login_attempts + 1;
      let lockUntil = null;

      // Lock account after 5 failed attempts for 30 minutes
      if (failedAttempts >= 5) {
        lockUntil = new Date(Date.now() + 30 * 60 * 1000); // 30 minutes
      }

      await pool.query(
        `UPDATE users 
         SET failed_login_attempts = $1, locked_until = $2 
         WHERE id = $3`,
        [failedAttempts, lockUntil, user.id]
      );

      return res.status(401).json({
        error: "Invalid credentials",
        message: "Phone/email or password is incorrect.",
        attemptsRemaining: Math.max(0, 5 - failedAttempts),
      });
    }

    // Reset failed login attempts and update last login
    await pool.query(
      `UPDATE users 
       SET failed_login_attempts = 0, locked_until = NULL, last_login = NOW() 
       WHERE id = $1`,
      [user.id]
    );

    // Generate JWT token
    const token = jwt.sign(
      {
        userId: user.id,
        phone: user.phone,
        email: user.email,
      },
      JWT_SECRET,
      { expiresIn: "7d" }
    );

    console.log(
      `User logged in: ${user.first_name} ${user.last_name} (${user.phone})`
    );

    res.status(200).json({
      success: true,
      message: "Login successful!",
      token,
      user: {
        id: user.id,
        phone: user.phone,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        preferences: {
          lighting: user.lighting_preference,
          business: user.business_preference,
          crime: user.crime_preference,
          reports: user.reports_preference,
        },
      },
    });
  } catch (err) {
    console.error("Error during login:", err);
    res.status(500).json({ error: "Login failed. Please try again." });
  }
};

// Get user profile (protected route)
const getUserProfile = async (req, res) => {
  try {
    const userId = req.user.userId; // From JWT middleware

    const result = await pool.query(
      `SELECT id, phone, email, first_name, last_name, date_of_birth, 
              profile_picture, created_at, last_login,
              lighting_preference, business_preference, crime_preference, reports_preference
       FROM users 
       WHERE id = $1 AND is_active = true`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    const user = result.rows[0];
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
        preferences: {
          lighting: user.lighting_preference,
          business: user.business_preference,
          crime: user.crime_preference,
          reports: user.reports_preference,
        },
      },
    });
  } catch (err) {
    console.error("Error fetching user profile:", err);
    res.status(500).json({ error: "Error fetching user profile" });
  }
};

// Update user profile
const updateUserProfile = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { firstName, lastName, dateOfBirth, profilePicture } = req.body;

    const result = await pool.query(
      `UPDATE users 
       SET first_name = COALESCE($1, first_name),
           last_name = COALESCE($2, last_name),
           date_of_birth = COALESCE($3, date_of_birth),
           profile_picture = COALESCE($4, profile_picture)
       WHERE id = $5 AND is_active = true
       RETURNING id, phone, email, first_name, last_name, date_of_birth, profile_picture,
                 lighting_preference, business_preference, crime_preference, reports_preference`,
      [firstName, lastName, dateOfBirth, profilePicture, userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    const user = result.rows[0];
    res.status(200).json({
      success: true,
      message: "Profile updated successfully",
      user: {
        id: user.id,
        phone: user.phone,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        dateOfBirth: user.date_of_birth,
        profilePicture: user.profile_picture,
        preferences: {
          lighting: user.lighting_preference,
          business: user.business_preference,
          crime: user.crime_preference,
          reports: user.reports_preference,
        },
      },
    });
  } catch (err) {
    console.error("Error updating user profile:", err);
    res.status(500).json({ error: "Error updating profile" });
  }
};

// Update user preferences
const updateUserPreferences = async (req, res) => {
  try {
    const userId = req.user.userId;
    const {
      lightingPreference,
      businessPreference,
      crimePreference,
      reportsPreference,
    } = req.body;

    // Validation
    if (
      lightingPreference === undefined ||
      businessPreference === undefined ||
      crimePreference === undefined ||
      reportsPreference === undefined
    ) {
      return res.status(400).json({
        error: "All preference values are required",
      });
    }

    const totalPreferences =
      lightingPreference +
      businessPreference +
      crimePreference +
      reportsPreference;
    if (Math.abs(totalPreferences - 1.0) > 0.01) {
      return res.status(400).json({
        error: "Safety preferences must sum to 1.0",
      });
    }

    // Validate each preference is between 0 and 1
    if (
      [
        lightingPreference,
        businessPreference,
        crimePreference,
        reportsPreference,
      ].some((pref) => pref < 0 || pref > 1)
    ) {
      return res.status(400).json({
        error: "Each preference must be between 0 and 1",
      });
    }

    const result = await pool.query(
      `UPDATE users 
       SET lighting_preference = $1, business_preference = $2, 
           crime_preference = $3, reports_preference = $4
       WHERE id = $5 AND is_active = true
       RETURNING lighting_preference, business_preference, crime_preference, reports_preference`,
      [
        lightingPreference,
        businessPreference,
        crimePreference,
        reportsPreference,
        userId,
      ]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    console.log(`User ${userId} updated safety preferences`);

    res.status(200).json({
      success: true,
      message: "Preferences updated successfully",
      preferences: {
        lighting: result.rows[0].lighting_preference,
        business: result.rows[0].business_preference,
        crime: result.rows[0].crime_preference,
        reports: result.rows[0].reports_preference,
      },
    });
  } catch (err) {
    console.error("Error updating preferences:", err);

    if (err.code === "23514") {
      // Constraint violation
      return res.status(400).json({
        error: "Invalid preferences",
        message: "Safety preferences must sum to 1.0.",
      });
    }

    res.status(500).json({ error: "Error updating preferences" });
  }
};

// Get available preference presets
const getPreferencePresets = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT name, description, lighting_weight, business_weight, crime_weight, reports_weight
       FROM user_preference_presets 
       WHERE is_active = true
       ORDER BY name`
    );

    res.status(200).json({
      success: true,
      presets: result.rows.map((preset) => ({
        name: preset.name,
        description: preset.description,
        weights: {
          lighting: preset.lighting_weight,
          business: preset.business_weight,
          crime: preset.crime_weight,
          reports: preset.reports_weight,
        },
      })),
    });
  } catch (err) {
    console.error("Error fetching preference presets:", err);
    res.status(500).json({ error: "Error fetching preference presets" });
  }
};

// Change password
const changePassword = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        error: "Current password and new password are required",
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        error: "New password must be at least 6 characters long",
      });
    }

    // Get current password hash
    const result = await pool.query(
      `SELECT password_hash FROM users WHERE id = $1 AND is_active = true`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    const user = result.rows[0];

    // Verify current password
    const isValidPassword = await bcrypt.compare(
      currentPassword,
      user.password_hash
    );
    if (!isValidPassword) {
      return res.status(401).json({
        error: "Current password is incorrect",
      });
    }

    // Hash new password
    const newPasswordHash = await bcrypt.hash(newPassword, SALT_ROUNDS);

    // Update password
    await pool.query(`UPDATE users SET password_hash = $1 WHERE id = $2`, [
      newPasswordHash,
      userId,
    ]);

    console.log(`Password changed for user ID: ${userId}`);

    res.status(200).json({
      success: true,
      message: "Password changed successfully",
    });
  } catch (err) {
    console.error("Error changing password:", err);
    res.status(500).json({ error: "Error changing password" });
  }
};

// JWT Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({ error: "Access token required" });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: "Invalid or expired token" });
    }
    req.user = user;
    next();
  });
};

// Helper functions
const isValidEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

const isValidPhone = (phone) => {
  // Israeli phone number validation (basic)
  const phoneRegex = /^(\+972|0)?[5-9]\d{8}$/;
  return phoneRegex.test(phone.replace(/[-\s]/g, ""));
};

module.exports = {
  registerUser,
  loginUser,
  getUserProfile,
  updateUserProfile,
  updateUserPreferences,
  getPreferencePresets,
  changePassword,
  authenticateToken,
};
