const request = require('supertest');
const app = require('../src/index');
const jwt = require('jsonwebtoken');
const { cleanupDatabase, createTestUser } = require('./setup');

describe('Reports Endpoints', () => {
  let testUser;
  let authToken;

  beforeEach(async () => {
    await cleanupDatabase();
    testUser = await createTestUser();
    authToken = jwt.sign(
      { userId: testUser.id, email: testUser.email },
      process.env.JWT_SECRET || 'test-secret',
      { expiresIn: '1h' }
    );
  });

  describe('POST /api/reports/submit', () => {
    test('should submit report successfully', async () => {
      const reportData = {
        category: 'poor_lighting',
        description: 'Street light is broken',
        urgencyLevel: 'medium',
        latitude: 32.0853,
        longitude: 34.7818
      };

      const response = await request(app)
        .post('/api/reports/submit')
        .set('Authorization', `Bearer ${authToken}`)
        .send(reportData);

      expect(response.status).toBe(201);
      expect(response.body.success).toBe(true);
      expect(response.body.report.category).toBe(reportData.category);
      expect(response.body.report.description).toBe(reportData.description);
      expect(response.body.report.latitude).toBe(reportData.latitude);
    });

    test('should reject report without auth token', async () => {
      const reportData = {
        category: 'poor_lighting',
        description: 'Street light is broken',
        urgencyLevel: 'medium',
        latitude: 32.0853,
        longitude: 34.7818
      };

      const response = await request(app)
        .post('/api/reports/submit')
        .send(reportData);

      expect(response.status).toBe(401);
      expect(response.body.error).toBe('Access token required');
    });

    test('should reject report with invalid category', async () => {
      const reportData = {
        category: 'invalid_category',
        description: 'Test description',
        urgencyLevel: 'medium',
        latitude: 32.0853,
        longitude: 34.7818
      };

      const response = await request(app)
        .post('/api/reports/submit')
        .set('Authorization', `Bearer ${authToken}`)
        .send(reportData);

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Invalid category');
    });

    test('should reject report with invalid coordinates', async () => {
      const reportData = {
        category: 'poor_lighting',
        description: 'Test description',
        urgencyLevel: 'medium',
        latitude: 200, // Invalid latitude
        longitude: 34.7818
      };

      const response = await request(app)
        .post('/api/reports/submit')
        .set('Authorization', `Bearer ${authToken}`)
        .send(reportData);

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Invalid coordinates');
    });
  });

  describe('GET /api/reports/nearby', () => {
    beforeEach(async () => {
      // Create test report
      await request(app)
        .post('/api/reports/submit')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          category: 'poor_lighting',
          description: 'Test report',
          urgencyLevel: 'medium',
          latitude: 32.0853,
          longitude: 34.7818
        });
    });

    test('should get nearby reports successfully', async () => {
      const response = await request(app)
        .get('/api/reports/nearby')
        .query({
          lat: 32.0853,
          lng: 34.7818,
          radius: 1
        });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.reports).toBeInstanceOf(Array);
      expect(response.body.reports.length).toBeGreaterThan(0);
    });

    test('should reject request without coordinates', async () => {
      const response = await request(app)
        .get('/api/reports/nearby');

      expect(response.status).toBe(400);
      expect(response.body.error).toBe('Latitude and longitude are required');
    });
  });
});