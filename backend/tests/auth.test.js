const request = require("supertest");
const app = require("../src/index");
const { cleanupDatabase, createTestUser } = require("./setup");

describe("Authentication Endpoints", () => {
  beforeEach(async () => {
    await cleanupDatabase();
  });

  describe("POST /api/auth/register", () => {
    test("should register new user successfully", async () => {
      const userData = {
        phone: "0501234567",
        email: "newuser@example.com",
        password: "password123",
        firstName: "John",
        lastName: "Doe",
      };

      const response = await request(app)
        .post("/api/auth/register")
        .send(userData);

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.token).toBeDefined();
      expect(response.body.user.email).toBe(userData.email);
      expect(response.body.user.firstName).toBe(userData.firstName);
    });

    test("should reject registration with invalid email", async () => {
      const userData = {
        phone: "0501234567",
        email: "invalid-email",
        password: "password123",
        firstName: "John",
        lastName: "Doe",
      };

      const response = await request(app)
        .post("/api/auth/register")
        .send(userData);

      expect(response.status).toBe(400);
      expect(response.body.error).toBe("Please provide a valid email address");
    });

    test("should reject registration with short password", async () => {
      const userData = {
        phone: "0501234567",
        email: "test@example.com",
        password: "123",
        firstName: "John",
        lastName: "Doe",
      };

      const response = await request(app)
        .post("/api/auth/register")
        .send(userData);

      expect(response.status).toBe(400);
      expect(response.body.error).toBe(
        "Password must be at least 6 characters long"
      );
    });

    test("should reject duplicate email registration", async () => {
      await createTestUser({ email: "duplicate@example.com" });

      const userData = {
        phone: "0509876543",
        email: "duplicate@example.com",
        password: "password123",
        firstName: "Jane",
        lastName: "Smith",
      };

      const response = await request(app)
        .post("/api/auth/register")
        .send(userData);

      expect(response.status).toBe(409);
      expect(response.body.error).toBe("Email already registered");
    });
  });

  describe("POST /api/auth/login", () => {
    let testUser;

    beforeEach(async () => {
      testUser = await createTestUser();
    });

    test("should login with valid credentials", async () => {
      const response = await request(app).post("/api/auth/login").send({
        phoneOrEmail: testUser.email,
        password: "password123",
      });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.token).toBeDefined();
      expect(response.body.user.email).toBe(testUser.email);
    });

    test("should reject login with invalid password", async () => {
      const response = await request(app).post("/api/auth/login").send({
        phoneOrEmail: testUser.email,
        password: "wrongpassword",
      });

      expect(response.status).toBe(401);
      expect(response.body.error).toBe("Invalid credentials");
    });

    test("should reject login with non-existent user", async () => {
      const response = await request(app).post("/api/auth/login").send({
        phoneOrEmail: "nonexistent@example.com",
        password: "password123",
      });

      expect(response.status).toBe(401);
      expect(response.body.error).toBe("Invalid credentials");
    });
  });
});
