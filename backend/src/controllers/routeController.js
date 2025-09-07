// routeController.js
const { getRoutesFromGoogle } = require("../services/googleDirectionsService");
const { scoreRoute, scoreRoutes } = require("../services/routeScoringService");
const pool = require("../db/pool");

// POST /route/calculate - calculates and scores multiple routes with user preferences
const calculateRoute = async (req, res) => {
  const { origin, destination, userId } = req.body;

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
    // Get user preferences if userId provided
    let userPreferences = {
      lighting: 0.3,
      business: 0.25,
      crime: 0.2,
      reports: 0.25,
    };

    let preferencesSource = "default";

    if (userId) {
      try {
        const userResult = await pool.query(
          `SELECT lighting_preference, business_preference, crime_preference, reports_preference,
                  first_name, last_name
           FROM users 
           WHERE id = $1 AND is_active = true`,
          [userId]
        );

        if (userResult.rows.length > 0) {
          const prefs = userResult.rows[0];
          userPreferences = {
            lighting: prefs.lighting_preference,
            business: prefs.business_preference,
            crime: prefs.crime_preference,
            reports: prefs.reports_preference,
          };
          preferencesSource = "user_profile";
          console.log(
            `Using custom preferences for user ${prefs.first_name} ${prefs.last_name}:`,
            userPreferences
          );
        } else {
          console.log(`User ${userId} not found, using default preferences`);
        }
      } catch (prefError) {
        console.warn(
          "Could not load user preferences, using defaults:",
          prefError.message
        );
        preferencesSource = "fallback_default";
      }
    } else {
      console.log("No userId provided, using default preferences");
    }

    // Get alternative routes from Google
    const routes = await getRoutesFromGoogle(origin, destination);

    if (!routes || routes.length === 0) {
      return res.status(404).json({
        error: "No routes found between the specified points",
      });
    }

    // Score all routes with user preferences
    let routeScores;
    try {
      // Extract just the paths for scoring
      const routePaths = routes.map((route) => route.path);
      routeScores = await scoreRoutes(routePaths, userPreferences);
    } catch (scoringError) {
      console.warn(
        "New scoring system failed, falling back to individual scoring:",
        scoringError.message
      );
      // Fallback to individual scoring
      routeScores = await Promise.all(
        routes.map(
          async (route) => await scoreRoute(route.path, userPreferences)
        )
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
        reportsScore: scoreData.reportsScore,

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

        // User preference information
        userPreferences: userPreferences,
        preferencesSource: preferencesSource,

        // Detailed breakdown for transparency
        scoreBreakdown: scoreData.breakdown,
      };
    });

    // Sort by safety score (descending)
    scoredRoutes.sort((a, b) => b.score - a.score);

    // Create preference summary for response
    const preferenceWeights = {
      lighting: `${Math.round(userPreferences.lighting * 100)}%`,
      business: `${Math.round(userPreferences.business * 100)}%`,
      crime: `${Math.round(userPreferences.crime * 100)}%`,
      reports: `${Math.round(userPreferences.reports * 100)}%`,
    };

    // Response with all routes and recommended one
    res.status(200).json({
      success: true,
      routeCount: scoredRoutes.length,
      routes: scoredRoutes,
      recommendation: scoredRoutes[0],
      scoringInfo: {
        preferencesUsed: preferenceWeights,
        preferencesSource: preferencesSource,
        scoringMethod: "user_weighted_normalization",
        message:
          preferencesSource === "user_profile"
            ? "Routes calculated using your personal safety preferences"
            : "Routes calculated using default safety preferences",
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
