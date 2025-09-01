// src/services/businessService.js
const axios = require("axios");

const GOOGLE_API_KEY = process.env.GOOGLE_MAPS_API_KEY;
const RADIUS_METERS = 300;

// Cache for business data
const businessCache = new Map();
const hours = 4;
const CACHE_DURATION = hours * 60 * 60 * 1000;

async function getOpenBusinesses(lat, lng) {
  const cacheKey = `${Math.round(lat * 1000)}_${Math.round(lng * 1000)}`;

  // Check cache first
  if (businessCache.has(cacheKey)) {
    const cached = businessCache.get(cacheKey);
    if (Date.now() - cached.timestamp < CACHE_DURATION) {
      console.log(`Cache hit for businesses at ${lat},${lng}`);
      return cached.data;
    } else {
      // Remove expired cache entry
      businessCache.delete(cacheKey);
    }
  }

  try {
    const url = `https://maps.googleapis.com/maps/api/place/nearbysearch/json`;
    const params = {
      location: `${lat},${lng}`,
      radius: RADIUS_METERS,
      type: "establishment", 
      key: GOOGLE_API_KEY,
      opennow: true,
    };

    console.log(`Making single business API call for ${lat},${lng}`);
    const res = await axios.get(url, { params });

    if (res.data.status !== "OK") {
      console.warn(`Business API warning: ${res.data.status}`);
      return { type: "FeatureCollection", features: [] };
    }

    const businesses = res.data.results || [];

    // Filter for relevant business types
    const relevantTypes = [
      "restaurant",
      "cafe",
      "bar",
      "store",
      "shop",
      "retail",
      "food",
    ];
    const filteredBusinesses = businesses.filter(
      (biz) =>
        biz.types &&
        biz.types.some((type) =>
          relevantTypes.some((relevant) => type.includes(relevant))
        )
    );

    // Create GeoJSON FeatureCollection
    const geojson = {
      type: "FeatureCollection",
      features: filteredBusinesses.map((biz) => ({
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [biz.geometry.location.lng, biz.geometry.location.lat],
        },
        properties: {
          name: biz.name,
          type: biz.types.join(", "),
          level: "medium",
          rating: biz.rating || null,
          place_id: biz.place_id,
        },
      })),
    };

    // Cache the result
    businessCache.set(cacheKey, {
      data: geojson,
      timestamp: Date.now(),
    });

    console.log(
      `Found ${geojson.features.length} businesses, cached for future use`
    );
    return geojson;
  } catch (error) {
    console.error(
      `Error fetching businesses for ${lat},${lng}:`,
      error.message
    );
    // Return empty result on error
    return { type: "FeatureCollection", features: [] };
  }
}

// Clean up old cache entries (call this periodically)
function cleanupCache() {
  const now = Date.now();
  for (const [key, value] of businessCache.entries()) {
    if (now - value.timestamp > CACHE_DURATION) {
      businessCache.delete(key);
    }
  }
}

// Clean cache every hour
setInterval(cleanupCache, 60 * 60 * 1000);

module.exports = { getOpenBusinesses };
