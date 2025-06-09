const { getRoutesFromGoogle } = require("../services/googleDirectionsService");
const { scoreRoute } = require("../services/routeScoringService");

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
    return res.status(400).json({
      error: "origin and destination must be [lat, lng] arrays",
    });
  }

  try {
    console.log(`Calculating routes from [${origin}] to [${destination}]`);

    // Get routes from Google
    const routes = await getRoutesFromGoogle(origin, destination);

    if (!routes || routes.length === 0) {
      return res.status(404).json({
        error: "No routes found between the specified points",
      });
    }

    // Score each route
    const scoredRoutes = await Promise.all(
      routes.map(async (route) => {
        try {
          const safetyScore = await scoreRoute(route.path);
          return {
            routeId: route.routeId,
            score: safetyScore,
            path: route.path,
            pathLength: route.path.length,
            estimatedSafety: getSafetyLevel(safetyScore),
          };
        } catch (error) {
          console.warn(
            `Failed to score route ${route.routeId}:`,
            error.message
          );
          return {
            routeId: route.routeId,
            score: 50,
            path: route.path,
            pathLength: route.path.length,
            estimatedSafety: "unknown",
          };
        }
      })
    );

    // Sort routes by safety score (desc)
    scoredRoutes.sort((a, b) => b.score - a.score);

    console.log(`Successfully calculated ${scoredRoutes.length} routes`);

    res.status(200).json({
      success: true,
      routeCount: scoredRoutes.length,
      routes: scoredRoutes,
      recommendation: scoredRoutes[0],
    });
  } catch (error) {
    console.error("Failed to calculate routes:", error);
    res.status(500).json({
      error: "Failed to calculate routes",
      details:
        process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

const getSafetyLevel = (score) => {
  if (score >= 80) return "very_safe";
  if (score >= 60) return "safe";
  if (score >= 40) return "moderate";
  if (score >= 20) return "risky";
  return "dangerous";
};

module.exports = { calculateRoute };
