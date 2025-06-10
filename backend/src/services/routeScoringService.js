const { getLayerDataForSafety } = require("./mapLayersService");
const { getOpenBusinesses } = require("./businessService");

// Layer weights: sum to 1.0 (100%)
const LAYER_WEIGHTS = {
  lighting: 0.5, // Street lighting – 50%
  business: 0.45, // Business density – 45%
  crime: -0.05, // Crime data – 5% (negative)
  reports: 0, // Live user reports – 0%
};

const SEARCH_RADIUS_KM = 0.1; // 100m
const SAMPLE_DISTANCE_KM = 0.05; // 50m sampling interval

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
      const features = await getLayerDataForSafety(layer);

      if (features && features.length > 0) {
        for (const feature of features) {
          if (!feature.geometry || !feature.geometry.coordinates) continue;
          const [lng, lat] = feature.geometry.coordinates;
          if (isNaN(lat) || isNaN(lng)) continue;

          const gridKey = `${Math.floor(lat * 1000)}_${Math.floor(lng * 1000)}`;
          if (!grid.has(gridKey)) {
            grid.set(gridKey, { lat, lng, scores: {} });
          }

          const level = feature.properties?.level || "medium";
          const levelMultiplier = getLevelMultiplier(level);
          const score = weight * levelMultiplier;
          grid.get(gridKey).scores[layer] = score;
        }
      }
    } catch (error) {
      // If fetching the layer fails, just skip it
      continue;
    }
  }

  cachedSafetyData = grid;
  cacheTimestamp = now;
  return grid;
};

// Main route scoring function: returns an object with score, lightingCount, businessCount
const scoreRoute = async (path) => {
  if (!path || path.length < 2) {
    return { score: 0, lightingCount: 0, businessCount: 0 };
  }

  const safetyGrid = await buildSafetyGrid();
  const sampledPath = samplePath(path, SAMPLE_DISTANCE_KM);

  let totalScore = 0;
  let scoredPoints = 0;
  let totalBusinessCount = 0;
  let totalLightingCount = 0;

  for (const [lat, lng] of sampledPath) {
    const nearbyScores = findNearbyScores(lat, lng, safetyGrid);

    // Count lighting points by positive lighting scores in grid
    const lightingScores = nearbyScores.filter((s) => s > 0);
    totalLightingCount += lightingScores.length;

    if (nearbyScores.length > 0) {
      const avgScore =
        nearbyScores.reduce((sum, score) => sum + score, 0) /
        nearbyScores.length;
      totalScore += avgScore;
      scoredPoints++;
    }

    try {
      // Count open businesses at this sample point
      const businessesGeo = await getOpenBusinesses(lat, lng);
      totalBusinessCount += businessesGeo.features.length;
    } catch (err) {
      // Ignore API failures, just skip this point
    }
  }

  let normalizedScore = 50;
  if (scoredPoints > 0) {
    const rawScore = totalScore / scoredPoints;
    normalizedScore = Math.max(0, Math.min(100, 50 + rawScore * 10));
  }

  const avgBusinessCount = totalBusinessCount / sampledPath.length;
  const businessScore = Math.min(1, avgBusinessCount / 10);
  const businessWeighted = businessScore * (LAYER_WEIGHTS.business * 100);

  const finalScore = Math.round(
    normalizedScore *
      (LAYER_WEIGHTS.lighting +
        Math.abs(LAYER_WEIGHTS.crime) +
        Math.abs(LAYER_WEIGHTS.reports)) +
      businessWeighted
  );

  // Return both score and feature counts
  return {
    score: Math.max(0, Math.min(100, finalScore)),
    lightingCount: totalLightingCount,
    businessCount: totalBusinessCount,
  };
};

// Path sampling (every X kilometers)
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

// Multiplier for severity/level string
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

// Distance calculation in kilometers
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
