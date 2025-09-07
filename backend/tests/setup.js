const { Pool } = require("pg");
require("dotenv").config({ path: ".env.test" });

// Test database setup
const testPool = new Pool({
  host: process.env.DB_HOST || "localhost",
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME_TEST || "city_path_test",
  user: process.env.DB_USER || "postgres",
  password: process.env.DB_PASSWORD || "password",
});

// Clean up database before each test
async function cleanupDatabase() {
  await testPool.query("DELETE FROM user_reputation_log");
  await testPool.query("DELETE FROM report_votes");
  await testPool.query("DELETE FROM user_badges");
  await testPool.query("DELETE FROM reports");
  await testPool.query("DELETE FROM users");
  await testPool.query("ALTER SEQUENCE users_id_seq RESTART WITH 1");
  await testPool.query("ALTER SEQUENCE reports_id_seq RESTART WITH 1");
}

// Create test user
async function createTestUser(userData = {}) {
  const defaultUser = {
    phone: "0501234567",
    email: "test@example.com",
    password_hash: "$2b$12$test.hash.here", // Pre-hashed password: 'password123'
    first_name: "Test",
    last_name: "User",
    reputation_score: 50,
    badge_level: "newcomer",
    ...userData,
  };

  const result = await testPool.query(
    `INSERT INTO users (phone, email, password_hash, first_name, last_name, reputation_score, badge_level, created_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, NOW()) RETURNING *`,
    [
      defaultUser.phone,
      defaultUser.email,
      defaultUser.password_hash,
      defaultUser.first_name,
      defaultUser.last_name,
      defaultUser.reputation_score,
      defaultUser.badge_level,
    ]
  );

  return result.rows[0];
}

module.exports = {
  testPool,
  cleanupDatabase,
  createTestUser,
};
