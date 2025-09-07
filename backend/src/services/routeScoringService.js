// routeScoringService.js - Updated to use user preferences
const { getLayerDataForSafety } = require("./mapLayersService");
const { getOpenBusinesses } = require("./businessService");
const pool = require("../db/pool");

// Default layer weights - used when no user preferences provided
const DEFAULT_LAYER_WEIGHTS = {
  lighting: 0.3, // Street lighting – 30%
  business: 0.25, // Business density – 25%
  crime: 0.2, // Crime data – 20%
  reports: 0.25, // Live user reports – 25%
};

const SEARCH_RADIUS_KM = 0.1; // 100m for all layers
const SAMPLE_DISTANCE_KM = 0.1; // 100m sampling interval

let cachedSafetyData = null;
let cacheTimestamp = 0;
const CACHE_DURATION = 3 * 60 * 60 * 1000; // 3 hours

// Get live user reports from database
const getActiveReports = async () => {
  try {
    const result = await pool.query(`
      SELECT 
        category,
        urgency_level,
        latitude,
        longitude,
        upvotes,
        downvotes,
        created_at
      FROM reports 
      WHERE is_active = true 
        AND expires_at > NOW()
        AND created_at > NOW() - INTERVAL '3 days'
      ORDER BY created_at DESC
    `);

    return result.rows.map((row) => ({
      category: row.category,
      urgencyLevel: row.urgency_level,
      latitude: parseFloat(row.latitude),
      longitude: parseFloat(row.longitude),
      upvotes: row.upvotes,
      downvotes: row.downvotes,
      createdAt: row.created_at,
    }));
  } catch (error) {
    console.warn("Failed to get active reports:", error.message);
    return [];
  }
};

const buildSafetyGrid = async () => {
  const now = Date.now();
  if (cachedSafetyData && now - cacheTimestamp < CACHE_DURATION) {
    return cachedSafetyData;
  }

  console.log("Building safety grid...");
  const grid = new Map();

  // Process traditional layers (lighting, business, crime)
  for (const [layer, weight] of Object.entries(DEFAULT_LAYER_WEIGHTS)) {
    if (weight === 0 || layer === "reports") continue; // Skip reports here, handle separately

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

          if (layer === "crime") {
            if (!grid.get(gridKey).scores[layer]) {
              grid.get(gridKey).scores[layer] = 0;
            }
            grid.get(gridKey).scores[layer] += levelMultiplier;
          } else {
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

  // Process user reports
  if (DEFAULT_LAYER_WEIGHTS.reports > 0) {
    try {
      const reports = await getActiveReports();
      console.log(`Processing ${reports.length} user reports`);

      for (const report of reports) {
        const {
          latitude,
          longitude,
          category,
          urgencyLevel,
          upvotes,
          downvotes,
        } = report;

        if (isNaN(latitude) || isNaN(longitude)) continue;

        const gridKey = `${Math.floor(latitude * 1000)}_${Math.floor(
          longitude * 1000
        )}`;
        if (!grid.has(gridKey)) {
          grid.set(gridKey, { lat: latitude, lng: longitude, scores: {} });
        }

        // Calculate report impact score
        const reportImpact = calculateReportImpact(
          category,
          urgencyLevel,
          upvotes,
          downvotes
        );

        if (!grid.get(gridKey).scores.reports) {
          grid.get(gridKey).scores.reports = 0;
        }

        // Accumulate negative reports (reduce safety score)
        grid.get(gridKey).scores.reports += reportImpact;
      }
    } catch (error) {
      console.warn("Failed to process user reports:", error.message);
    }
  }

  cachedSafetyData = grid;
  cacheTimestamp = now;
  console.log(`Safety grid built with ${grid.size} points`);
  return grid;
};

// Calculate impact of a user report on safety score
const calculateReportImpact = (category, urgencyLevel, upvotes, downvotes) => {
  // Base impact by category (negative impact = reduces safety)
  const categoryImpact = {
    poor_lighting: -1.0,
    suspicious_gathering: -1.5,
    road_hazard: -1.2,
    violence_assault: -2.0,
    harassment: -1.8,
    police_security: 1.5, // Positive impact
  };

  // Urgency multiplier
  const urgencyMultiplier = {
    low: 0.5,
    medium: 1.0,
    high: 1.8,
  };

  // Verification score based on upvotes/downvotes
  const totalVotes = upvotes + downvotes;
  let verificationMultiplier = 1.0;

  if (totalVotes >= 3) {
    const upvoteRatio = upvotes / totalVotes;
    if (upvoteRatio >= 0.7) {
      verificationMultiplier = 1.5; // Well-verified reports have more impact
    } else if (upvoteRatio <= 0.3) {
      verificationMultiplier = 0.3; // Disputed reports have less impact
    }
  }

  const baseImpact = categoryImpact[category] || -1.0;
  const urgency = urgencyMultiplier[urgencyLevel] || 1.0;

  return baseImpact * urgency * verificationMultiplier;
};

// Collect route data including reports
const collectRouteData = async (path) => {
  if (!path || path.length < 2) {
    return {
      lightingCount: 0,
      businessCount: 0,
      crimeCount: 0,
      reportsCount: 0,
      routeLengthKm: 0,
      lightingDensity: 0,
      businessDensity: 0,
      crimeDensity: 0,
      reportsDensity: 0,
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
  let totalReportsImpact = 0;
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

    // Count user reports impact
    const nearbyReportsScores = findNearbyScores(
      lat,
      lng,
      safetyGrid,
      "reports"
    );
    const reportsImpact = nearbyReportsScores.reduce(
      (sum, score) => sum + Math.abs(score),
      0
    );
    totalReportsImpact += reportsImpact;

    // Count businesses (with cache)
    try {
      const businessesGeo = await getOpenBusinesses(lat, lng);
      totalBusinessCount += businessesGeo.features.length;
      businessAPICallsMade++;
    } catch (err) {
      console.warn(`Business API failed for point ${lat},${lng}:`, err.message);
    }
  }

  // Calculate densities
  const lightingDensity =
    routeLengthKm > 0 ? totalLightingCount / routeLengthKm : 0;
  const businessDensity =
    routeLengthKm > 0 ? totalBusinessCount / routeLengthKm : 0;
  const crimeDensity = routeLengthKm > 0 ? totalCrimeCount / routeLengthKm : 0;
  const reportsDensity =
    routeLengthKm > 0 ? totalReportsImpact / routeLengthKm : 0;

  return {
    lightingCount: totalLightingCount,
    businessCount: totalBusinessCount,
    crimeCount: totalCrimeCount,
    reportsCount: Math.round(totalReportsImpact * 10) / 10,
    routeLengthKm: Math.round(routeLengthKm * 1000) / 1000,
    lightingDensity: Math.round(lightingDensity * 100) / 100,
    businessDensity: Math.round(businessDensity * 100) / 100,
    crimeDensity: Math.round(crimeDensity * 100) / 100,
    reportsDensity: Math.round(reportsDensity * 100) / 100,
    sampledPoints: sampledPath.length,
    apiCallsMade: businessAPICallsMade,
  };
};

// Score multiple routes with user preferences
const scoreRoutes = async (allRoutesPaths, userPreferences = null) => {
  if (!allRoutesPaths || allRoutesPaths.length === 0) {
    return [];
  }

  // Use user preferences or default weights
  const weights = userPreferences || DEFAULT_LAYER_WEIGHTS;

  console.log(
    `Scoring ${allRoutesPaths.length} routes with preferences:`,
    weights
  );

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
  const maxReportsDensity = Math.max(
    ...routesData.map((r) => r.reportsDensity)
  );

  // Calculate scores with user preferences
  const scoredRoutes = routesData.map((routeData, index) => {
    const lightingScore =
      maxLightingDensity > 0
        ? (routeData.lightingDensity / maxLightingDensity) * 100
        : 50;

    const businessScore =
      maxBusinessDensity > 0
        ? (routeData.businessDensity / maxBusinessDensity) * 100
        : 50;

    // Crime score is INVERTED
    const crimeScore =
      maxCrimeDensity > 0
        ? 100 - (routeData.crimeDensity / maxCrimeDensity) * 100
        : 100;

    // Reports score is INVERTED
    const reportsScore =
      maxReportsDensity > 0
        ? 100 - (routeData.reportsDensity / maxReportsDensity) * 100
        : 100;

    // Calculate weighted final score using user preferences
    const finalScore = Math.round(
      lightingScore * weights.lighting +
        businessScore * weights.business +
        crimeScore * weights.crime +
        reportsScore * weights.reports
    );

    console.log(
      `Route ${index + 1} scored: ${finalScore}% (L:${Math.round(
        lightingScore
      )}% B:${Math.round(businessScore)}% C:${Math.round(
        crimeScore
      )}% R:${Math.round(reportsScore)}%) [Weights: L:${Math.round(
        weights.lighting * 100
      )}% B:${Math.round(weights.business * 100)}% C:${Math.round(
        weights.crime * 100
      )}% R:${Math.round(weights.reports * 100)}%]`
    );

    return {
      ...routeData,
      lightingScore: Math.round(lightingScore * 100) / 100,
      businessScore: Math.round(businessScore * 100) / 100,
      crimeScore: Math.round(crimeScore * 100) / 100,
      reportsScore: Math.round(reportsScore * 100) / 100,
      score: finalScore,
      userWeights: weights, // Include user weights in response
      breakdown: {
        lightingContribution:
          Math.round(lightingScore * weights.lighting * 100) / 100,
        businessContribution:
          Math.round(businessScore * weights.business * 100) / 100,
        crimeContribution: Math.round(crimeScore * weights.crime * 100) / 100,
        reportsContribution:
          Math.round(reportsScore * weights.reports * 100) / 100,
      },
    };
  });

  return scoredRoutes;
};

// Score single route with user preferences
const scoreRoute = async (path, userPreferences = null) => {
  const routes = await scoreRoutes([path], userPreferences);
  return (
    routes[0] || {
      score: 50,
      lightingScore: 50,
      businessScore: 50,
      crimeScore: 50,
      reportsScore: 50,
      breakdown: {
        lightingContribution: 0,
        businessContribution: 0,
        crimeContribution: 0,
        reportsContribution: 0,
      },
    }
  );
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

// Path sampling
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

// Multiplier for severity
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
  scoreRoute,
  buildSafetyGrid,
  DEFAULT_LAYER_WEIGHTS,
  calculateRouteDistance,
  SAMPLE_DISTANCE_KM,
};
