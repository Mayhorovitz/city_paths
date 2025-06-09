// import_lighting_layer.js
require("dotenv").config(); // חובה אם מריצים מחוץ ל־src!
const { Pool } = require("pg");

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

const getLevel = (lampCount) => {
  if (lampCount >= 6) return "critical";
  if (lampCount >= 4) return "high";
  if (lampCount >= 2) return "medium";
  return "low";
};

async function run() {
  try {
    const res = await pool.query(
      "SELECT id, lamp_count, ST_X(location::geometry) as lng, ST_Y(location::geometry) as lat FROM lighting_poles"
    );

    const features = res.rows.map((row) => ({
      type: "Feature",
      geometry: {
        type: "Point",
        coordinates: [row.lng, row.lat],
      },
      properties: {
        poleId: row.id,
        level: getLevel(row.lamp_count),
        lampCount: row.lamp_count,
      },
    }));

    const geojson = {
      type: "FeatureCollection",
      features: features,
    };

    // שמירה לטבלת layers
    await pool.query(
      `INSERT INTO layers (type, data, updated_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (type)
       DO UPDATE SET data = $2, updated_at = NOW()`,
      ["lighting", geojson]
    );

    console.log(
      `Imported ${features.length} lighting poles to layers as GeoJSON.`
    );
    process.exit(0);
  } catch (err) {
    console.error("Error:", err);
    process.exit(1);
  }
}

run();
