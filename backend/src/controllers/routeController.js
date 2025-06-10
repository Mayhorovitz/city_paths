const { getRoutesFromGoogle } = require("../services/googleDirectionsService");
const { scoreRoute } = require("../services/routeScoringService");

// POST /route/calculate - calculates and scores multiple routes
const calculateRoute = async (req, res) => {
  const { origin, destination } = req.body;

  // Input validation
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
    // Get alternative routes from Google
    const routes = await getRoutesFromGoogle(origin, destination);

    if (!routes || routes.length === 0) {
      return res.status(404).json({
        error: "No routes found between the specified points",
      });
    }

    // Score each route and collect additional feature counts
    const scoredRoutes = await Promise.all(
      routes.map(async (route) => {
        try {
          const { score, lightingCount, businessCount } = await scoreRoute(
            route.path
          );
          return {
            routeId: route.routeId,
            score,
            lightingCount, // number of lighting features along the route
            businessCount, // number of open businesses along the route
            path: route.path,
            pathLength: route.path.length,
            estimatedSafety: getSafetyLevel(score),
          };
        } catch (error) {
          // If scoring failed, return a default route object
          return {
            routeId: route.routeId,
            score: 50,
            lightingCount: 0,
            businessCount: 0,
            path: route.path,
            pathLength: route.path.length,
            estimatedSafety: "unknown",
          };
        }
      })
    );

    // Sort by safety score (descending)
    scoredRoutes.sort((a, b) => b.score - a.score);

    // Response with all routes and recommended one
    res.status(200).json({
      success: true,
      routeCount: scoredRoutes.length,
      routes: scoredRoutes,
      recommendation: scoredRoutes[0],
    });
  } catch (error) {
    res.status(500).json({
      error: "Failed to calculate routes",
      details:
        process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

// Converts a numeric safety score to a textual level
const getSafetyLevel = (score) => {
  if (score >= 80) return "very_safe";
  if (score >= 60) return "safe";
  if (score >= 40) return "moderate";
  if (score >= 20) return "risky";
  return "dangerous";
};

module.exports = { calculateRoute };
