// backend/src/services/cleanupService.js
const pool = require("../db/pool");
const cron = require("node-cron");

class CleanupService {
  // Delete expired reports
  static async cleanupExpiredReports() {
    try {
      console.log("Starting cleanup of expired reports...");

      const result = await pool.query(`
        DELETE FROM reports 
        WHERE expires_at < NOW()
        RETURNING id, category, created_at
      `);

      const deletedCount = result.rows.length;

      if (deletedCount > 0) {
        console.log(`Cleaned up ${deletedCount} expired reports:`);
        result.rows.forEach((report) => {
          console.log(
            `- Report ${report.id} (${report.category}) from ${report.created_at}`
          );
        });
      } else {
        console.log("No expired reports found");
      }

      return { success: true, deletedCount };
    } catch (error) {
      console.error("Error during cleanup:", error);
      return { success: false, error: error.message };
    }
  }

  // Delete inactive reports (flagged as spam)
  static async cleanupInactiveReports() {
    try {
      console.log("Starting cleanup of inactive reports...");

      const result = await pool.query(`
        DELETE FROM reports 
        WHERE is_active = false 
        AND created_at < NOW() - INTERVAL '7 days'
        RETURNING id, category, created_at
      `);

      const deletedCount = result.rows.length;

      if (deletedCount > 0) {
        console.log(`Cleaned up ${deletedCount} inactive reports`);
      } else {
        console.log("No inactive reports to clean");
      }

      return { success: true, deletedCount };
    } catch (error) {
      console.error("Error cleaning inactive reports:", error);
      return { success: false, error: error.message };
    }
  }

  // General cleanup routine
  static async performDailyCleanup() {
    console.log("Starting daily cleanup routine...");

    const expiredResult = await this.cleanupExpiredReports();
    const inactiveResult = await this.cleanupInactiveReports();

    const totalDeleted =
      (expiredResult.deletedCount || 0) + (inactiveResult.deletedCount || 0);

    console.log(
      `Daily cleanup completed! Total deleted: ${totalDeleted} reports`
    );

    return {
      success: true,
      expiredDeleted: expiredResult.deletedCount || 0,
      inactiveDeleted: inactiveResult.deletedCount || 0,
      totalDeleted,
    };
  }

  // Start the scheduled cron job
  static startScheduledCleanup() {
    // Run every day at 2:00 AM
    cron.schedule(
      "0 2 * * *",
      async () => {
        await this.performDailyCleanup();
      },
      {
        timezone: "Asia/Jerusalem",
      }
    );

    console.log("Cleanup cron job scheduled for 2:00 AM daily");

    // Also run on startup for testing
    setTimeout(async () => {
      console.log("Running initial cleanup...");
      await this.performDailyCleanup();
    }, 5000); // After 5 seconds from startup
  }
}

module.exports = CleanupService;
