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

      route.legs.forEach((leg) => {
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
      };
    });
  } catch (err) {
    console.error("Error fetching directions from Google:", err.message);
    throw err;
  }
};

module.exports = { getRoutesFromGoogle };
