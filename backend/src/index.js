const express = require("express");
const cors = require("cors");

const CleanupService = require("./services/cleanupService");

require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json());

app.use("/uploads", express.static("uploads"));

app.get("/", (req, res) => {
  res.send("city paths Backend is running!");
});

//routes
const authRoutes = require("./routes/auth");
app.use("/api/auth", authRoutes);

const layerRoutes = require("./routes/layerRoutes");
app.use("/api/layers", layerRoutes);

const routeRoutes = require("./routes/routeRoutes");
app.use("/api/routes", routeRoutes);

const reportRoutes = require("./routes/reportsRoutes");
app.use("/api/reports", reportRoutes);

const usersRoutes = require("./routes/usersRoutes");
app.use("/api/users", usersRoutes);

const feedbackRoutes = require("./routes/feedbackRoutes");
app.use("/api/feedback", feedbackRoutes);

// Manual cleanup endpoint (for testing)
app.get("/api/admin/cleanup", async (req, res) => {
  try {
    const result = await CleanupService.performDailyCleanup();
    res.json({
      success: true,
      message: "Cleanup completed successfully",
      result,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: "Cleanup failed",
      details: error.message,
    });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, "0.0.0.0", () => {
  CleanupService.startScheduledCleanup();

  console.log(`Server running on port ${PORT}`);
});
