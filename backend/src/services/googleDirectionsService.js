// backend\src\services\googleDirectionsService.js
const axios = require("axios");

const GOOGLE_API_KEY = process.env.GOOGLE_MAPS_API_KEY;

const getRoutesFromGoogle = async (origin, destination) => {
  const url = "https://maps.googleapis.com/maps/api/directions/json";

  const params = {
    origin: `${origin[0]},${origin[1]}`,
    destination: `${destination[0]},${destination[1]}`,
    alternatives: true,
    mode: "walking",
    key: GOOGLE_API_KEY,
  };

  try {
    const response = await axios.get(url, { params });
    const routes = response.data.routes;

    return routes.map((route, i) => {
      const path = [];

      // Extract duration and distance from the route
      let totalDuration = 0;
      let totalDistance = 0;

      route.legs.forEach((leg) => {
        // Add leg duration and distance to totals
        totalDuration += leg.duration.value; // in seconds
        totalDistance += leg.distance.value; // in meters

        leg.steps.forEach((step) => {
          const start = step.start_location;
          path.push([start.lat, start.lng]);
        });
        const end = leg.steps.at(-1)?.end_location;
        if (end) path.push([end.lat, end.lng]);
      });

      return {
        routeId: i + 1,
        path,
        duration: {
          seconds: totalDuration,
          minutes: Math.round(totalDuration / 60),
          text:
            route.legs[0]?.duration?.text ||
            `${Math.round(totalDuration / 60)} mins`,
        },
        distance: {
          meters: totalDistance,
          kilometers: Math.round((totalDistance / 1000) * 1000) / 1000, // Round to 3 decimal places
          text:
            route.legs[0]?.distance?.text ||
            `${(totalDistance / 1000).toFixed(1)} km`,
        },
        // Keep the original Google route data for reference
        googleRouteData: {
          summary: route.summary,
          warnings: route.warnings,
          waypoint_order: route.waypoint_order,
        },
      };
    });
  } catch (err) {
    console.error("Error fetching directions from Google:", err.message);
    throw err;
  }
};

module.exports = { getRoutesFromGoogle };
