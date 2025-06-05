const { getRoutesFromGoogle } = require("../services/googleDirectionsService");

const calculateRoute = async (req, res) => {
  const { origin, destination } = req.body;

  if (
    !origin ||
    !destination ||
    !Array.isArray(origin) ||
    !Array.isArray(destination) ||
    origin.length !== 2 ||
    destination.length !== 2
  ) {
    return res
      .status(400)
      .json({ error: "origin and destination must be [lat, lng]" });
  }

  try {
    const routes = await getRoutesFromGoogle(origin, destination);

    const response = routes.map((route, i) => ({
      routeId: route.routeId,
      score: null,
      path: route.path,
    }));

    res.status(200).json(response);
  } catch (err) {
    console.error("Failed to calculate route:", err);
    res.status(500).json({ error: "Failed to calculate route" });
  }
};

module.exports = { calculateRoute };
