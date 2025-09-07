// backend/src/services/cleanupService.js
const pool = require("../db/pool");
const cron = require("node-cron");

class CleanupService {
  // Mark expired reports as inactive instead of deleting them
  static async cleanupExpiredReports() {
    try {
      console.log("Starting cleanup of expired reports...");

      // Update expired reports to inactive status instead of deleting
      // This preserves data for analytics and avoids foreign key constraint issues
      const result = await pool.query(`
        UPDATE reports 
        SET is_active = false 
        WHERE expires_at < NOW() AND is_active = true
        RETURNING id, category, created_at
      `);

      const deactivatedCount = result.rows.length;

      if (deactivatedCount > 0) {
        console.log(`Deactivated ${deactivatedCount} expired reports:`);
        result.rows.forEach((report) => {
          console.log(
            `- Report ${report.id} (${report.category}) from ${report.created_at}`
          );
        });
      } else {
        console.log("No expired reports found");
      }

      return { success: true, deactivatedCount };
    } catch (error) {
      console.error("Error during cleanup:", error);
      return { success: false, error: error.message };
    }
  }

  // Keep inactive reports cleanup for spam reports - they can be deleted after 7 days
  static async cleanupInactiveReports() {
    try {
      console.log("Starting cleanup of inactive reports...");

      // Only delete reports that were manually flagged as spam/inactive
      const result = await pool.query(`
        DELETE FROM reports 
        WHERE is_active = false 
        AND created_at < NOW() - INTERVAL '7 days'
        AND id NOT IN (
          SELECT DISTINCT related_report_id 
          FROM user_reputation_log 
          WHERE related_report_id IS NOT NULL
        )
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

    // Update terminology to reflect that expired reports are deactivated, not deleted
    const totalDeactivated = expiredResult.deactivatedCount || 0;
    const totalDeleted = inactiveResult.deletedCount || 0;

    console.log(
      `Daily cleanup completed! Deactivated: ${totalDeactivated} expired reports, Deleted: ${totalDeleted} spam reports`
    );

    return {
      success: true,
      expiredDeactivated: expiredResult.deactivatedCount || 0,
      inactiveDeleted: inactiveResult.deletedCount || 0,
      totalProcessed: totalDeactivated + totalDeleted,
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
