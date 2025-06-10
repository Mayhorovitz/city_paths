// routeScoringService.js - Updated with relative normalization
const { getLayerDataForSafety } = require("./mapLayersService");
const { getOpenBusinesses } = require("./businessService");

// Layer weights: sum to 95% (no crime data for now)
const LAYER_WEIGHTS = {
  lighting: 0.5, // Street lighting – 50%
  business: 0.45, // Business density – 45%
  crime: 0.05, // Crime data – 5% (will be perfect score for now)
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

// Calculate total route distance in kilometers
const calculateRouteDistance = (path) => {
  if (!path || path.length < 2) return 0;

  let totalDistance = 0;
  for (let i = 1; i < path.length; i++) {
    totalDistance += haversineDistance(
      path[i - 1][0],
      path[i - 1][1],
      path[i][0],
      path[i][1]
    );
  }
  return totalDistance;
};

// Collect route data without scoring (for relative normalization)
const collectRouteData = async (path) => {
  if (!path || path.length < 2) {
    return {
      lightingCount: 0,
      businessCount: 0,
      routeLengthKm: 0,
      lightingDensity: 0,
      businessDensity: 0,
    };
  }

  const safetyGrid = await buildSafetyGrid();
  const sampledPath = samplePath(path, SAMPLE_DISTANCE_KM);
  const routeLengthKm = calculateRouteDistance(path);

  let totalBusinessCount = 0;
  let totalLightingCount = 0;

  for (const [lat, lng] of sampledPath) {
    const nearbyScores = findNearbyScores(lat, lng, safetyGrid);

    // Count lighting points by positive lighting scores in grid
    const lightingScores = nearbyScores.filter((s) => s > 0);
    totalLightingCount += lightingScores.length;

    try {
      // Count open businesses at this sample point
      const businessesGeo = await getOpenBusinesses(lat, lng);
      totalBusinessCount += businessesGeo.features.length;
    } catch (err) {
      // Ignore API failures, just skip this point
    }
  }

  // Calculate densities (features per kilometer)
  const lightingDensity =
    routeLengthKm > 0 ? totalLightingCount / routeLengthKm : 0;
  const businessDensity =
    routeLengthKm > 0 ? totalBusinessCount / routeLengthKm : 0;

  return {
    lightingCount: totalLightingCount,
    businessCount: totalBusinessCount,
    routeLengthKm: Math.round(routeLengthKm * 1000) / 1000,
    lightingDensity: Math.round(lightingDensity * 100) / 100,
    businessDensity: Math.round(businessDensity * 100) / 100,
  };
};

// Score multiple routes with relative normalization
const scoreRoutes = async (allRoutesPaths) => {
  if (!allRoutesPaths || allRoutesPaths.length === 0) {
    return [];
  }

  // Collect data for all routes first
  const routesData = await Promise.all(
    allRoutesPaths.map(async (routePath) => {
      return await collectRouteData(routePath);
    })
  );

  // Find maximum densities across all routes
  const maxLightingDensity = Math.max(
    ...routesData.map((r) => r.lightingDensity)
  );
  const maxBusinessDensity = Math.max(
    ...routesData.map((r) => r.businessDensity)
  );

  // Calculate scores with relative normalization
  const scoredRoutes = routesData.map((routeData) => {
    // Calculate component scores (0-100 scale)
    const lightingScore =
      maxLightingDensity > 0
        ? (routeData.lightingDensity / maxLightingDensity) * 100
        : 0;

    const businessScore =
      maxBusinessDensity > 0
        ? (routeData.businessDensity / maxBusinessDensity) * 100
        : 0;

    // Crime score is perfect (100) since we don't have crime data
    const crimeScore = 100;

    // Calculate weighted final score
    const finalScore = Math.round(
      lightingScore * LAYER_WEIGHTS.lighting +
        businessScore * LAYER_WEIGHTS.business +
        crimeScore * LAYER_WEIGHTS.crime
    );

    return {
      ...routeData,
      lightingScore: Math.round(lightingScore * 100) / 100,
      businessScore: Math.round(businessScore * 100) / 100,
      crimeScore: Math.round(crimeScore * 100) / 100,
      score: finalScore,
      breakdown: {
        lightingContribution:
          Math.round(lightingScore * LAYER_WEIGHTS.lighting * 100) / 100,
        businessContribution:
          Math.round(businessScore * LAYER_WEIGHTS.business * 100) / 100,
        crimeContribution:
          Math.round(crimeScore * LAYER_WEIGHTS.crime * 100) / 100,
      },
    };
  });

  return scoredRoutes;
};

// Legacy function for backward compatibility - now just calls the new system
const scoreRoute = async (path) => {
  const results = await scoreRoutes([path]);
  return (
    results[0] || {
      score: 0,
      lightingCount: 0,
      businessCount: 0,
      routeLengthKm: 0,
      lightingDensity: 0,
      businessDensity: 0,
      lightingScore: 0,
      businessScore: 0,
      crimeScore: 0,
    }
  );
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
  scoreRoutes, // New function for scoring multiple routes
  buildSafetyGrid,
  LAYER_WEIGHTS,
  calculateRouteDistance,
};
