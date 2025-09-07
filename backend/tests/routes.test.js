const request = require("supertest");
const app = require("../src/index");
const { cleanupDatabase } = require("./setup");

describe("Routes Endpoints", () => {
  beforeEach(async () => {
    await cleanupDatabase();
  });

  describe("POST /api/routes/calculate", () => {
    test("should calculate route successfully", async () => {
      const routeData = {
        origin: [32.0853, 34.7818], // Tel Aviv coordinates
        destination: [32.09, 34.79],
      };

      const response = await request(app)
        .post("/api/routes/calculate")
        .send(routeData);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.routes).toBeInstanceOf(Array);
      expect(response.body.routes.length).toBeGreaterThan(0);
      expect(response.body.recommendation).toBeDefined();
    });

    test("should reject invalid origin coordinates", async () => {
      const routeData = {
        origin: [200, 34.7818], // Invalid latitude
        destination: [32.09, 34.79],
      };

      const response = await request(app)
        .post("/api/routes/calculate")
        .send(routeData);

      expect(response.status).toBe(400);
      expect(response.body.error).toBe(
        "origin and destination must be [lat, lng] arrays"
      );
    });

    test("should reject missing destination", async () => {
      const routeData = {
        origin: [32.0853, 34.7818],
        // destination missing
      };

      const response = await request(app)
        .post("/api/routes/calculate")
        .send(routeData);

      expect(response.status).toBe(400);
      expect(response.body.error).toBe(
        "origin and destination must be [lat, lng] arrays"
      );
    });
  });
});
