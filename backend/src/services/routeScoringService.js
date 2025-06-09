const { getLayerData } = require("./mapLayersService");

// Weights per the spec (total 100%)
const LAYER_WEIGHTS = {
  lighting: 0.3, // Street lighting – 30%
  business: 0.25, // Business density – 25%
  userRatings: 0.2, // User ratings – 20%
  crime: -0.15, // Crime data – 15% (negative)
  reports: -0.1, // Live user reports – 10% (negative)
};

const SEARCH_RADIUS_KM = 0.1; // 100m
const SAMPLE_DISTANCE_KM = 0.05; // 50m sampling interval

// Fast in-memory cache for safety grid
let cachedSafetyData = null;
let cacheTimestamp = 0;
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

const buildSafetyGrid = async () => {
  const now = Date.now();
  if (cachedSafetyData && now - cacheTimestamp < CACHE_DURATION) {
    return cachedSafetyData;
  }

  const grid = new Map();

  for (const [layer, weight] of Object.entries(LAYER_WEIGHTS)) {
    try {
      const features = await getLayerData(layer);
      for (const feature of features) {
        const [lng, lat] = feature.geometry.coordinates;
        const gridKey = `${Math.floor(lat * 1000)}_${Math.floor(lng * 1000)}`;
        if (!grid.has(gridKey)) {
          grid.set(gridKey, { lat, lng, scores: {} });
        }
        const level = feature.properties.level || "medium";
        const levelMultiplier = getLevelMultiplier(level);
        grid.get(gridKey).scores[layer] = weight * levelMultiplier;
      }
    } catch (error) {
      console.warn(`Failed to load ${layer} data:`, error.message);
    }
  }

  cachedSafetyData = grid;
  cacheTimestamp = now;
  return grid;
};

// Main scoring function
const scoreRoute = async (path) => {
  if (!path || path.length < 2) return 0;

  const safetyGrid = await buildSafetyGrid();

  const sampledPath = samplePath(path, SAMPLE_DISTANCE_KM);
  let totalScore = 0;
  let scoredPoints = 0;

  for (const [lat, lng] of sampledPath) {
    const nearbyScores = findNearbyScores(lat, lng, safetyGrid);

    if (nearbyScores.length > 0) {
      const avgScore =
        nearbyScores.reduce((sum, score) => sum + score, 0) /
        nearbyScores.length;
      totalScore += avgScore;
      scoredPoints++;
    }
  }

  if (scoredPoints === 0) return 50; // default score if no data

  // Normalize to 0-100
  const rawScore = totalScore / scoredPoints;
  const normalizedScore = Math.max(0, Math.min(100, 50 + rawScore * 10));
  return Math.round(normalizedScore);
};

// Sample path every X kilometers
const samplePath = (path, intervalKm) => {
  if (path.length <= 2) return path;

  const sampledPoints = [path[0]];
  let accumulatedDistance = 0;

  for (let i = 1; i < path.length; i++) {
    const segmentDistance = haversineDistance(
      path[i - 1][0],
      path[i - 1][1],
      path[i][0],
      path[i][1]
    );
    accumulatedDistance += segmentDistance;
    if (accumulatedDistance >= intervalKm) {
      sampledPoints.push(path[i]);
      accumulatedDistance = 0;
    }
  }
  if (sampledPoints[sampledPoints.length - 1] !== path[path.length - 1]) {
    sampledPoints.push(path[path.length - 1]);
  }
  return sampledPoints;
};

// Finds safety scores for points within SEARCH_RADIUS_KM
const findNearbyScores = (lat, lng, safetyGrid) => {
  const scores = [];
  const gridRange = Math.ceil(SEARCH_RADIUS_KM * 1000);

  for (let latOffset = -gridRange; latOffset <= gridRange; latOffset++) {
    for (let lngOffset = -gridRange; lngOffset <= gridRange; lngOffset++) {
      const gridKey = `${Math.floor(lat * 1000) + latOffset}_${
        Math.floor(lng * 1000) + lngOffset
      }`;
      const gridPoint = safetyGrid.get(gridKey);
      if (gridPoint) {
        const distance = haversineDistance(
          lat,
          lng,
          gridPoint.lat,
          gridPoint.lng
        );
        if (distance <= SEARCH_RADIUS_KM) {
          const pointScore = Object.values(gridPoint.scores).reduce(
            (sum, score) => sum + score,
            0
          );
          scores.push(pointScore);
        }
      }
    }
  }

  return scores;
};

// Convert severity to multiplier
const getLevelMultiplier = (level) => {
  switch (level?.toLowerCase()) {
    case "low":
      return 0.5;
    case "medium":
      return 1.0;
    case "high":
      return 1.5;
    case "critical":
      return 2.0;
    default:
      return 1.0;
  }
};

function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(a));
}
function toRad(degrees) {
  return degrees * (Math.PI / 180);
}

module.exports = {
  scoreRoute,
  buildSafetyGrid,
  LAYER_WEIGHTS,
};
