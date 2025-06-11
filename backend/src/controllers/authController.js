const pool = require("../db/pool");

// 5 digits random verification code
const generateCode = () => Math.floor(10000 + Math.random() * 90000);

// Check if user exists
const checkUserExists = async (phone, email) => {
  const result = await pool.query(
    `SELECT id, phone, email, verified FROM users WHERE phone = $1 OR email = $2`,
    [phone, email]
  );
  return result.rows[0] || null;
};

// Handle user registration (new users only)
const registerUser = async (req, res) => {
  const { phone, email } = req.body;

  if (!phone || !email) {
    return res.status(400).json({ error: "Phone and email are required" });
  }

  try {
    // Check if user already exists
    const existingUser = await checkUserExists(phone, email);

    if (existingUser) {
      return res.status(409).json({
        error: "User already exists",
        message:
          "This phone or email is already registered. Please use login instead.",
      });
    }

    const code = generateCode();

    // Insert new user
    const result = await pool.query(
      `
        INSERT INTO users (phone, email, preferences, verified)
        VALUES ($1, $2, jsonb_build_object('code', $3::text), false)
        RETURNING id, phone, email
        `,
      [phone, email, code]
    );

    console.log(`Registration code for new user ${phone}: ${code}`);

    res.status(201).json({
      message: "Registration successful! Verification code sent.",
      user: {
        id: result.rows[0].id,
        phone: result.rows[0].phone,
        email: result.rows[0].email,
      },
    });
  } catch (err) {
    console.error("Error during registration:", err);

    // Handle duplicate key error specifically
    if (err.code === "23505") {
      return res.status(409).json({
        error: "User already exists",
        message: "This phone or email is already registered.",
      });
    }

    res.status(500).json({ error: "Error during registration" });
  }
};

// Handle user login (existing users only)
const loginUser = async (req, res) => {
  const { phone, email } = req.body;

  if (!phone && !email) {
    return res.status(400).json({ error: "Phone or email is required" });
  }

  try {
    // Check if user exists
    const existingUser = await checkUserExists(phone || email, email || phone);

    if (!existingUser) {
      return res.status(404).json({
        error: "User not found",
        message:
          "No account found with this phone or email. Please register first.",
      });
    }

    const code = generateCode();

    // Update existing user with new verification code
    await pool.query(
      `
        UPDATE users 
        SET preferences = jsonb_build_object('code', $1::text)
        WHERE id = $2
        `,
      [code, existingUser.id]
    );

    console.log(`Login code for existing user ${existingUser.phone}: ${code}`);

    res.status(200).json({
      message: "Login code sent successfully!",
      user: {
        id: existingUser.id,
        phone: existingUser.phone,
        email: existingUser.email,
        verified: existingUser.verified,
      },
    });
  } catch (err) {
    console.error("Error during login:", err);
    res.status(500).json({ error: "Error during login" });
  }
};

// Handle code verification (same for both register and login)
const verifyCode = async (req, res) => {
  const { phone, code } = req.body;

  if (!phone || !code) {
    return res.status(400).json({ error: "Phone and code are required" });
  }

  try {
    const result = await pool.query(
      `SELECT id, phone, email, preferences, verified FROM users WHERE phone = $1`,
      [phone]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    const user = result.rows[0];
    const storedCode = user.preferences?.code;

    if (!storedCode) {
      return res
        .status(400)
        .json({ error: "No verification code found for this user" });
    }

    if (storedCode === code.toString()) {
      // Update user: set verified = true and remove code from preferences
      const updateResult = await pool.query(
        `
          UPDATE users
          SET verified = true,
              preferences = preferences - 'code'
          WHERE phone = $1
          RETURNING id, phone, email, verified, created_at
          `,
        [phone]
      );

      const updatedUser = updateResult.rows[0];

      return res.status(200).json({
        message: "Verification successful",
        user: {
          id: updatedUser.id,
          phone: updatedUser.phone,
          email: updatedUser.email,
          verified: updatedUser.verified,
          created_at: updatedUser.created_at,
        },
      });
    } else {
      return res.status(401).json({ error: "Invalid verification code" });
    }
  } catch (err) {
    console.error("Error during verification:", err);
    res.status(500).json({ error: "Error during verification" });
  }
};

// Get user profile (optional - for authenticated routes)
const getUserProfile = async (req, res) => {
  const { phone } = req.params;

  try {
    const result = await pool.query(
      `SELECT id, phone, email, verified, created_at FROM users WHERE phone = $1 AND verified = true`,
      [phone]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found or not verified" });
    }

    res.status(200).json({ user: result.rows[0] });
  } catch (err) {
    console.error("Error fetching user profile:", err);
    res.status(500).json({ error: "Error fetching user profile" });
  }
};

module.exports = {
  registerUser,
  loginUser,
  verifyCode,
  getUserProfile,
  checkUserExists,
};
