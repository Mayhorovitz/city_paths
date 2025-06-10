// src/services/businessService.js
const axios = require("axios");

const GOOGLE_API_KEY = process.env.GOOGLE_MAPS_API_KEY;
const RADIUS_METERS = 300;

async function getOpenBusinesses(lat, lng) {
  const types = ["restaurant", "cafe", "bar", "store"];

  let allResults = [];
  for (const type of types) {
    const url = `https://maps.googleapis.com/maps/api/place/nearbysearch/json`;
    const params = {
      location: `${lat},${lng}`,
      radius: RADIUS_METERS,
      type,
      key: GOOGLE_API_KEY,
      opennow: true, // onlt opens buisnesess
    };
    const res = await axios.get(url, { params });
    allResults = allResults.concat(res.data.results || []);
  }

  // remove doplicate
  const unique = {};
  allResults.forEach((biz) => (unique[biz.place_id] = biz));
  const businesses = Object.values(unique);

  // GeoJSON FeatureCollection
  const geojson = {
    type: "FeatureCollection",
    features: businesses.map((biz) => ({
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
      },
    })),
  };

  return geojson;
}

module.exports = { getOpenBusinesses };
