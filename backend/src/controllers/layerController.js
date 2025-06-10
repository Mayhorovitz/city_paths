// backend\src\controllers\layerController.js
const pool = require("../db/pool");

// Original function - for Express routes
const getLayerData = async (req, res) => {
  const { type } = req.query;

  if (!type) {
    return res.status(400).json({ error: "Layer type is required" });
  }

  try {
    const result = await pool.query(
      `SELECT data FROM layers WHERE type = $1 ORDER BY updated_at DESC LIMIT 1`,
      [type]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Layer not found" });
    }

    res.status(200).json(result.rows[0].data);
  } catch (err) {
    res.status(500).json({ error: "Error fetching layer data" });
  }
};

// New function - for safety logic usage
const getLayerDataForSafety = async (layerType) => {
  try {
    const result = await pool.query(
      `SELECT data FROM layers WHERE type = $1 ORDER BY updated_at DESC LIMIT 1`,
      [layerType]
    );

    if (result.rows.length === 0) {
      return [];
    }

    const data = result.rows[0].data;

    // Check if data is GeoJSON features
    if (data && data.features && Array.isArray(data.features)) {
      return data.features;
    } else if (Array.isArray(data)) {
      return data;
    } else {
      return [];
    }
  } catch (err) {
    return [];
  }
};

module.exports = {
  getLayerData, // Express middleware
  getLayerDataForSafety, // For safety code logic
};
