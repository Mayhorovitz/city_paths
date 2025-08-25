const express = require("express");
const cors = require("cors");
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

const PORT = process.env.PORT || 3000;
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
});
