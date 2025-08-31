const { getLayerData } = require("./mapLayersService");

// Relevant safety layers
const LAYERS = ["crime", "lighting", "business", "reports"];

// Weight per layer
const LAYER_WEIGHTS = {
  crime: -1, // crime lowers the score
  lighting: 1, // lighting improves the score
  business: 0.7, // business presence improves the score
  reports: -0.8, // negative user reports lower the score
};

// Main scoring function for a full route
const scoreRoute = async (path) => {
  let totalScore = 0;

  for (const coord of path) {
    const [lat, lng] = coord;

    for (const layer of LAYERS) {
      // Load features from each safety layer
      const features = await getLayerData(layer); // returns GeoJSON FeatureCollection

      for (const feature of features) {
        const [featLng, featLat] = feature.geometry.coordinates;
        const distance = haversineDistance(lat, lng, featLat, featLng);

        // Consider nearby features within 50 meters
        if (distance < 0.05) {
          const level = feature.properties.level || "medium";
          const weight = getLevelMultiplier(level);
          totalScore += LAYER_WEIGHTS[layer] * weight;
        }
      }
    }
  }

  // Round to one decimal place
  return Math.round(totalScore * 10) / 10;
};

// Convert severity level to multiplier
const getLevelMultiplier = (level) => {
  switch (level) {
    case "low":
      return 0.5;
    case "medium":
      return 1;
    case "high":
      return 1.5;
    default:
      return 1;
  }
};

// Calculate distance between two lat/lng points using the Haversine formula
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth radius in kilometers
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(a));
}

// Convert degrees to radians
function toRad(degrees) {
  return degrees * (Math.PI / 180);
}

module.exports = { scoreRoute };
