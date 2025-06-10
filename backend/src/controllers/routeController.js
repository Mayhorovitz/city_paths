// routeController.js - Updated to use the new scoring system
const { getRoutesFromGoogle } = require("../services/googleDirectionsService");
const { scoreRoute, scoreRoutes } = require("../services/routeScoringService");

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

    // Score all routes with relative normalization
    let routeScores;
    try {
      // Extract just the paths for scoring
      const routePaths = routes.map((route) => route.path);
      routeScores = await scoreRoutes(routePaths);
    } catch (scoringError) {
      console.warn(
        "New scoring system failed, falling back to individual scoring:",
        scoringError.message
      );
      // Fallback to individual scoring
      routeScores = await Promise.all(
        routes.map(async (route) => await scoreRoute(route.path))
      );
    }

    // Combine Google route data with our scoring data
    const scoredRoutes = routes.map((route, index) => {
      const scoreData = routeScores[index];

      return {
        routeId: route.routeId,
        score: scoreData.score,

        // Safety component scores for UI display
        lightingScore: scoreData.lightingScore,
        businessScore: scoreData.businessScore,
        crimeScore: scoreData.crimeScore,

        // Google data - duration and distance
        walkingTime: {
          minutes: route.duration.minutes,
          text: route.duration.text,
        },
        distance: {
          kilometers: route.distance.kilometers,
          text: route.distance.text,
        },

        // Route geometry
        path: route.path,
        pathLength: route.path.length,
        estimatedSafety: getSafetyLevel(scoreData.score),

        // Additional Google route info
        routeSummary: route.googleRouteData?.summary || "",
      };
    });

    // Sort by safety score (descending)
    scoredRoutes.sort((a, b) => b.score - a.score);

    // Response with all routes and recommended one
    res.status(200).json({
      success: true,
      routeCount: scoredRoutes.length,
      routes: scoredRoutes,
      recommendation: scoredRoutes[0],
      scoringInfo: {
        lightingWeight: "50%",
        businessWeight: "45%",
        crimeWeight: "5%",
        scoringMethod: "relative_normalization",
      },
    });
  } catch (error) {
    console.error("Route calculation error:", error);
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
