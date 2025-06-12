// routeScoringService.js
const { getLayerDataForSafety } = require("./mapLayersService");
const { getOpenBusinesses } = require("./businessService");

// Layer weights
const LAYER_WEIGHTS = {
  lighting: 0.45, // Street lighting – 45%
  business: 0.35, // Business density – 35%
  crime: 0.2, // Crime data – 20%
  reports: 0, // Live user reports – 0%
};

const SEARCH_RADIUS_KM = 0.1; // 100m for all layers
const SAMPLE_DISTANCE_KM = 0.1; // 100m sampling interval

let cachedSafetyData = null;
let cacheTimestamp = 0;
const CACHE_DURATION = 3 * 60 * 60 * 1000; // 3 hours

const buildSafetyGrid = async () => {
  const now = Date.now();
  if (cachedSafetyData && now - cacheTimestamp < CACHE_DURATION) {
    return cachedSafetyData;
  }

  console.log("Building safety grid...");
  const grid = new Map();

  for (const [layer, weight] of Object.entries(LAYER_WEIGHTS)) {
    if (weight === 0) continue; // Skip layers with 0 weight

    try {
      const features = await getLayerDataForSafety(layer);

      if (features && features.length > 0) {
        console.log(`Processing ${features.length} ${layer} features`);
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

          // For crime  store the severity weighted count
          if (layer === "crime") {
            if (!grid.get(gridKey).scores[layer]) {
              grid.get(gridKey).scores[layer] = 0;
            }
            grid.get(gridKey).scores[layer] += levelMultiplier;
          } else {
            // For lighting and business, store the weighted score as before
            const score = weight * levelMultiplier;
            grid.get(gridKey).scores[layer] = score;
          }
        }
      }
    } catch (error) {
      console.warn(`Failed to process ${layer} layer:`, error.message);
      continue;
    }
  }

  cachedSafetyData = grid;
  cacheTimestamp = now;
  console.log(`Safety grid built with ${grid.size} points`);
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
      crimeCount: 0,
      routeLengthKm: 0,
      lightingDensity: 0,
      businessDensity: 0,
      crimeDensity: 0,
    };
  }

  const safetyGrid = await buildSafetyGrid();
  const sampledPath = samplePath(path, SAMPLE_DISTANCE_KM);
  const routeLengthKm = calculateRouteDistance(path);

  console.log(
    `Analyzing route: ${path.length} points -> ${
      sampledPath.length
    } sampled points (every ${SAMPLE_DISTANCE_KM * 1000}m)`
  );

  let totalBusinessCount = 0;
  let totalLightingCount = 0;
  let totalCrimeCount = 0;
  let businessAPICallsMade = 0;

  for (const [lat, lng] of sampledPath) {
    // Count lighting from safety grid
    const nearbyLightingScores = findNearbyScores(
      lat,
      lng,
      safetyGrid,
      "lighting"
    );
    totalLightingCount += nearbyLightingScores.length;

    // Count crime incidents from safety grid
    const nearbyCrimeScores = findNearbyScores(lat, lng, safetyGrid, "crime");
    const crimeWeightedCount = nearbyCrimeScores.reduce(
      (sum, score) => sum + score,
      0
    );
    totalCrimeCount += crimeWeightedCount;

    // Count businesses (with cache)
    try {
      const businessesGeo = await getOpenBusinesses(lat, lng);
      totalBusinessCount += businessesGeo.features.length;
      businessAPICallsMade++;
    } catch (err) {
      console.warn(`Business API failed for point ${lat},${lng}:`, err.message);
    }
  }

  // Calculate densities (features per kilometer)
  const lightingDensity =
    routeLengthKm > 0 ? totalLightingCount / routeLengthKm : 0;
  const businessDensity =
    routeLengthKm > 0 ? totalBusinessCount / routeLengthKm : 0;
  const crimeDensity = routeLengthKm > 0 ? totalCrimeCount / routeLengthKm : 0;

  return {
    lightingCount: totalLightingCount,
    businessCount: totalBusinessCount,
    crimeCount: totalCrimeCount,
    routeLengthKm: Math.round(routeLengthKm * 1000) / 1000,
    lightingDensity: Math.round(lightingDensity * 100) / 100,
    businessDensity: Math.round(businessDensity * 100) / 100,
    crimeDensity: Math.round(crimeDensity * 100) / 100,
    sampledPoints: sampledPath.length,
    apiCallsMade: businessAPICallsMade,
  };
};

// Score multiple routes with relative normalization
const scoreRoutes = async (allRoutesPaths) => {
  if (!allRoutesPaths || allRoutesPaths.length === 0) {
    return [];
  }

  console.log(`Scoring ${allRoutesPaths.length} routes...`);

  // Collect data for all routes first
  const routesData = await Promise.all(
    allRoutesPaths.map(async (routePath, index) => {
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
  const maxCrimeDensity = Math.max(...routesData.map((r) => r.crimeDensity));

  // Calculate scores with relative normalization
  const scoredRoutes = routesData.map((routeData, index) => {
    const lightingScore =
      maxLightingDensity > 0
        ? (routeData.lightingDensity / maxLightingDensity) * 100
        : 0;

    const businessScore =
      maxBusinessDensity > 0
        ? (routeData.businessDensity / maxBusinessDensity) * 100
        : 0;

    // Crime score is INVERTED - higher crime density = lower score
    const crimeScore =
      maxCrimeDensity > 0
        ? 100 - (routeData.crimeDensity / maxCrimeDensity) * 100
        : 100;

    // Calculate weighted final score
    const finalScore = Math.round(
      lightingScore * LAYER_WEIGHTS.lighting +
        businessScore * LAYER_WEIGHTS.business +
        crimeScore * LAYER_WEIGHTS.crime
    );

    console.log(
      `Route ${index + 1} scored: ${finalScore}% (L:${Math.round(
        lightingScore
      )}% B:${Math.round(businessScore)}% C:${Math.round(crimeScore)}%)`
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

  // Always include the last point
  if (sampledPoints[sampledPoints.length - 1] !== path[path.length - 1]) {
    sampledPoints.push(path[path.length - 1]);
  }

  return sampledPoints;
};

// Find safety scores within SEARCH_RADIUS_KM for specific layer
const findNearbyScores = (lat, lng, safetyGrid, layer) => {
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
          const layerScore = gridPoint.scores[layer];
          if (layerScore !== undefined) {
            scores.push(layerScore);
          }
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
  scoreRoutes,
  buildSafetyGrid,
  LAYER_WEIGHTS,
  calculateRouteDistance,
  SAMPLE_DISTANCE_KM,
};
