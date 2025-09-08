// routeScoringService.js - Refactored with smaller, focused functions
const { getLayerDataForSafety } = require("./mapLayersService");
const { getOpenBusinesses } = require("./businessService");
const pool = require("../db/pool");

// Constants
const DEFAULT_LAYER_WEIGHTS = {
  lighting: 0.3,
  business: 0.25,
  crime: 0.2,
  reports: 0.25,
};

const SEARCH_RADIUS_KM = 0.1;
const SAMPLE_DISTANCE_KM = 0.1;
const CACHE_DURATION = 3 * 60 * 60 * 1000; // 3 hours

// Cache management
let cachedSafetyData = null;
let cacheTimestamp = 0;

const getActiveReports = async () => {
  try {
    const result = await pool.query(`
      SELECT 
        category, urgency_level, latitude, longitude,
        upvotes, downvotes, created_at
      FROM reports 
      WHERE is_active = true 
        AND expires_at > NOW()
        AND created_at > NOW() - INTERVAL '3 days'
      ORDER BY created_at DESC
    `);

    return result.rows.map(transformDatabaseReport);
  } catch (error) {
    console.warn("Failed to get active reports:", error.message);
    return [];
  }
};

const transformDatabaseReport = (row) => ({
  category: row.category,
  urgencyLevel: row.urgency_level,
  latitude: parseFloat(row.latitude),
  longitude: parseFloat(row.longitude),
  upvotes: row.upvotes,
  downvotes: row.downvotes,
  createdAt: row.created_at,
});

const isCacheValid = () => {
  return cachedSafetyData && Date.now() - cacheTimestamp < CACHE_DURATION;
};

const updateCache = (data) => {
  cachedSafetyData = data;
  cacheTimestamp = Date.now();
};
//build saftey grid
const buildSafetyGrid = async () => {
  if (isCacheValid()) {
    return cachedSafetyData;
  }

  console.log("Building safety grid...");
  const grid = new Map();

  await processTraditionalLayers(grid);
  await processUserReports(grid);

  updateCache(grid);
  console.log(`Safety grid built with ${grid.size} points`);
  return grid;
};
// Process traditional layers (lighting, business, crime)
const processTraditionalLayers = async (grid) => {
  const layersToProcess = Object.entries(DEFAULT_LAYER_WEIGHTS).filter(
    ([layer, weight]) => weight > 0 && layer !== "reports"
  );

  for (const [layer, weight] of layersToProcess) {
    await processLayerFeatures(grid, layer, weight);
  }
};

const processLayerFeatures = async (grid, layer, weight) => {
  try {
    const features = await getLayerDataForSafety(layer);
    if (!features || features.length === 0) return;

    console.log(`Processing ${features.length} ${layer} features`);

    features.forEach((feature) => {
      processFeature(grid, feature, layer, weight);
    });
  } catch (error) {
    console.warn(`Failed to process ${layer} layer:`, error.message);
  }
};

const processFeature = (grid, feature, layer, weight) => {
  if (!isValidFeature(feature)) return;

  const [lng, lat] = feature.geometry.coordinates;
  const gridKey = createGridKey(lat, lng);

  initializeGridPoint(grid, gridKey, lat, lng);
  updateGridScore(grid, gridKey, layer, feature, weight);
};

const isValidFeature = (feature) => {
  return (
    feature.geometry &&
    feature.geometry.coordinates &&
    !isNaN(feature.geometry.coordinates[0]) &&
    !isNaN(feature.geometry.coordinates[1])
  );
};

const createGridKey = (lat, lng) => {
  return `${Math.floor(lat * 1000)}_${Math.floor(lng * 1000)}`;
};

const initializeGridPoint = (grid, gridKey, lat, lng) => {
  if (!grid.has(gridKey)) {
    grid.set(gridKey, { lat, lng, scores: {} });
  }
};

const updateGridScore = (grid, gridKey, layer, feature, weight) => {
  const level = feature.properties?.level || "medium";
  const levelMultiplier = getLevelMultiplier(level);
  const gridPoint = grid.get(gridKey);

  if (layer === "crime") {
    gridPoint.scores[layer] = (gridPoint.scores[layer] || 0) + levelMultiplier;
  } else {
    gridPoint.scores[layer] = weight * levelMultiplier;
  }
};

const processUserReports = async (grid) => {
  if (DEFAULT_LAYER_WEIGHTS.reports <= 0) return;

  try {
    const reports = await getActiveReports();
    console.log(`Processing ${reports.length} user reports`);

    reports.forEach((report) => processReportImpact(grid, report));
  } catch (error) {
    console.warn("Failed to process user reports:", error.message);
  }
};

const processReportImpact = (grid, report) => {
  const { latitude, longitude, category, urgencyLevel, upvotes, downvotes } =
    report;

  if (isNaN(latitude) || isNaN(longitude)) return;

  const gridKey = createGridKey(latitude, longitude);
  initializeGridPoint(grid, gridKey, latitude, longitude);

  const reportImpact = calculateReportImpact(
    category,
    urgencyLevel,
    upvotes,
    downvotes
  );
  const gridPoint = grid.get(gridKey);
  gridPoint.scores.reports = (gridPoint.scores.reports || 0) + reportImpact;
};
// Calculate impact of a user report on safety score
const calculateReportImpact = (category, urgencyLevel, upvotes, downvotes) => {
  const baseImpact = getCategoryImpact(category);
  const urgencyMultiplier = getUrgencyMultiplier(urgencyLevel);
  const verificationMultiplier = getVerificationMultiplier(upvotes, downvotes);

  return baseImpact * urgencyMultiplier * verificationMultiplier;
};
// Base impact by category (negative impact = reduces safety)
const getCategoryImpact = (category) => {
  const categoryImpacts = {
    poor_lighting: -1.0,
    suspicious_gathering: -1.5,
    road_hazard: -1.2,
    violence_assault: -2.0,
    harassment: -1.8,
    police_security: 1.5,
  };
  return categoryImpacts[category] || -1.0;
};

const getUrgencyMultiplier = (urgencyLevel) => {
  const urgencyMultipliers = {
    low: 0.5,
    medium: 1.0,
    high: 1.8,
  };
  return urgencyMultipliers[urgencyLevel] || 1.0;
};
// Verification score based on upvotes/downvotes
const getVerificationMultiplier = (upvotes, downvotes) => {
  const totalVotes = upvotes + downvotes;
  if (totalVotes < 3) return 1.0;

  const upvoteRatio = upvotes / totalVotes;
  if (upvoteRatio >= 0.7) return 1.5;
  if (upvoteRatio <= 0.3) return 0.3;
  return 1.0;
};
// Multiplier for severity
const getLevelMultiplier = (level) => {
  const levelMultipliers = {
    low: 0.5,
    medium: 1.0,
    high: 1.5,
    critical: 2.0,
  };
  return levelMultipliers[level?.toLowerCase()] || 1.0;
};
// Collect route data including reports
const collectRouteData = async (path) => {
  if (!isValidPath(path)) {
    return createEmptyRouteData();
  }

  const routeMetrics = await initializeRouteMetrics(path);
  const layerCounts = await collectAllLayerData(
    routeMetrics.sampledPath,
    routeMetrics.safetyGrid
  );

  return calculateRouteDensities(layerCounts, routeMetrics);
};

const isValidPath = (path) => {
  return path && path.length >= 2;
};

const createEmptyRouteData = () => ({
  lightingCount: 0,
  businessCount: 0,
  crimeCount: 0,
  reportsCount: 0,
  routeLengthKm: 0,
  lightingDensity: 0,
  businessDensity: 0,
  crimeDensity: 0,
  reportsDensity: 0,
});

const initializeRouteMetrics = async (path) => {
  const safetyGrid = await buildSafetyGrid();
  const sampledPath = samplePath(path, SAMPLE_DISTANCE_KM);
  const routeLengthKm = calculateRouteDistance(path);

  console.log(
    `Analyzing route: ${path.length} points -> ${
      sampledPath.length
    } sampled points (every ${SAMPLE_DISTANCE_KM * 1000}m)`
  );

  return { safetyGrid, sampledPath, routeLengthKm };
};

const collectAllLayerData = async (sampledPath, safetyGrid) => {
  const layerCounts = {
    totalLightingCount: 0,
    totalBusinessCount: 0,
    totalCrimeCount: 0,
    totalReportsImpact: 0,
    businessAPICallsMade: 0,
  };

  for (const [lat, lng] of sampledPath) {
    await processPathPoint(lat, lng, safetyGrid, layerCounts);
  }

  return layerCounts;
};

const processPathPoint = async (lat, lng, safetyGrid, layerCounts) => {
  // Collect grid-based data
  collectGridBasedData(lat, lng, safetyGrid, layerCounts);

  // Collect business data from API
  await collectBusinessData(lat, lng, layerCounts);
};

const collectGridBasedData = (lat, lng, safetyGrid, layerCounts) => {
  const lightingScores = findNearbyScores(lat, lng, safetyGrid, "lighting");
  const crimeScores = findNearbyScores(lat, lng, safetyGrid, "crime");
  const reportsScores = findNearbyScores(lat, lng, safetyGrid, "reports");

  layerCounts.totalLightingCount += lightingScores.length;
  layerCounts.totalCrimeCount += crimeScores.reduce(
    (sum, score) => sum + score,
    0
  );
  layerCounts.totalReportsImpact += reportsScores.reduce(
    (sum, score) => sum + Math.abs(score),
    0
  );
};

const collectBusinessData = async (lat, lng, layerCounts) => {
  try {
    const businessesGeo = await getOpenBusinesses(lat, lng);
    layerCounts.totalBusinessCount += businessesGeo.features.length;
    layerCounts.businessAPICallsMade++;
  } catch (err) {
    console.warn(`Business API failed for point ${lat},${lng}:`, err.message);
  }
};

const calculateRouteDensities = (layerCounts, routeMetrics) => {
  const { routeLengthKm, sampledPath } = routeMetrics;
  const densityCalculator = (count) =>
    routeLengthKm > 0 ? count / routeLengthKm : 0;

  return {
    lightingCount: layerCounts.totalLightingCount,
    businessCount: layerCounts.totalBusinessCount,
    crimeCount: layerCounts.totalCrimeCount,
    reportsCount: Math.round(layerCounts.totalReportsImpact * 10) / 10,
    routeLengthKm: Math.round(routeLengthKm * 1000) / 1000,
    lightingDensity:
      Math.round(densityCalculator(layerCounts.totalLightingCount) * 100) / 100,
    businessDensity:
      Math.round(densityCalculator(layerCounts.totalBusinessCount) * 100) / 100,
    crimeDensity:
      Math.round(densityCalculator(layerCounts.totalCrimeCount) * 100) / 100,
    reportsDensity:
      Math.round(densityCalculator(layerCounts.totalReportsImpact) * 100) / 100,
    sampledPoints: sampledPath.length,
    apiCallsMade: layerCounts.businessAPICallsMade,
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

  const routesData = await collectAllRoutesData(allRoutesPaths);
  const maxDensities = findMaximumDensities(routesData);

  return calculateScoredRoutes(routesData, maxDensities, weights);
};

const collectAllRoutesData = async (routesPaths) => {
  return Promise.all(
    routesPaths.map((routePath) => collectRouteData(routePath))
  );
};

const findMaximumDensities = (routesData) => ({
  maxLightingDensity: Math.max(...routesData.map((r) => r.lightingDensity)),
  maxBusinessDensity: Math.max(...routesData.map((r) => r.businessDensity)),
  maxCrimeDensity: Math.max(...routesData.map((r) => r.crimeDensity)),
  maxReportsDensity: Math.max(...routesData.map((r) => r.reportsDensity)),
});

const calculateScoredRoutes = (routesData, maxDensities, weights) => {
  return routesData.map((routeData, index) => {
    const normalizedScores = calculateNormalizedScores(routeData, maxDensities);
    const finalScore = calculateWeightedScore(normalizedScores, weights);

    logRouteScore(index, finalScore, normalizedScores, weights);

    return createScoredRouteResult(
      routeData,
      normalizedScores,
      finalScore,
      weights
    );
  });
};

const calculateNormalizedScores = (routeData, maxDensities) => {
  const {
    maxLightingDensity,
    maxBusinessDensity,
    maxCrimeDensity,
    maxReportsDensity,
  } = maxDensities;

  return {
    lightingScore:
      maxLightingDensity > 0
        ? (routeData.lightingDensity / maxLightingDensity) * 100
        : 50,
    businessScore:
      maxBusinessDensity > 0
        ? (routeData.businessDensity / maxBusinessDensity) * 100
        : 50,
    crimeScore:
      maxCrimeDensity > 0
        ? 100 - (routeData.crimeDensity / maxCrimeDensity) * 100
        : 100,
    reportsScore:
      maxReportsDensity > 0
        ? 100 - (routeData.reportsDensity / maxReportsDensity) * 100
        : 100,
  };
};

const calculateWeightedScore = (scores, weights) => {
  return Math.round(
    scores.lightingScore * weights.lighting +
      scores.businessScore * weights.business +
      scores.crimeScore * weights.crime +
      scores.reportsScore * weights.reports
  );
};

const logRouteScore = (index, finalScore, scores, weights) => {
  console.log(
    `Route ${index + 1} scored: ${finalScore}% ` +
      `(L:${Math.round(scores.lightingScore)}% B:${Math.round(
        scores.businessScore
      )}% ` +
      `C:${Math.round(scores.crimeScore)}% R:${Math.round(
        scores.reportsScore
      )}%) ` +
      `[Weights: L:${Math.round(weights.lighting * 100)}% B:${Math.round(
        weights.business * 100
      )}% ` +
      `C:${Math.round(weights.crime * 100)}% R:${Math.round(
        weights.reports * 100
      )}%]`
  );
};

const createScoredRouteResult = (routeData, scores, finalScore, weights) => ({
  ...routeData,
  lightingScore: Math.round(scores.lightingScore * 100) / 100,
  businessScore: Math.round(scores.businessScore * 100) / 100,
  crimeScore: Math.round(scores.crimeScore * 100) / 100,
  reportsScore: Math.round(scores.reportsScore * 100) / 100,
  score: finalScore,
  userWeights: weights,
  breakdown: calculateScoreBreakdown(scores, weights),
});

const calculateScoreBreakdown = (scores, weights) => ({
  lightingContribution:
    Math.round(scores.lightingScore * weights.lighting * 100) / 100,
  businessContribution:
    Math.round(scores.businessScore * weights.business * 100) / 100,
  crimeContribution: Math.round(scores.crimeScore * weights.crime * 100) / 100,
  reportsContribution:
    Math.round(scores.reportsScore * weights.reports * 100) / 100,
});

const scoreRoute = async (path, userPreferences = null) => {
  const routes = await scoreRoutes([path], userPreferences);
  return routes[0] || createDefaultScore();
};

const createDefaultScore = () => ({
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
});

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

      if (gridPoint && isWithinRadius(lat, lng, gridPoint)) {
        const layerScore = gridPoint.scores[layer];
        if (layerScore !== undefined) {
          scores.push(layerScore);
        }
      }
    }
  }

  return scores;
};

const isWithinRadius = (lat, lng, gridPoint) => {
  const distance = haversineDistance(lat, lng, gridPoint.lat, gridPoint.lng);
  return distance <= SEARCH_RADIUS_KM;
};
// Distance calculation in kilometers
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth radius in kilometers
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
