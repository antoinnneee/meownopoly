const db = require('./database');

// TTL in hours — configurable via .env (TTL_HOURS), défaut 24 h.
// Avant, la valeur était codée en dur et TTL_HOURS dans .env était ignoré.
const TTL_HOURS = parseFloat(process.env.TTL_HOURS) || 24;

/**
 * Runs the cleanup process.
 */
function performCleanup() {
    try {
        console.log(`[Cleanup] Starting periodic cleanup (TTL: ${TTL_HOURS}h)...`);
        db.cleanupOldData(TTL_HOURS);
        console.log(`[Cleanup] Finished.`);
    } catch (err) {
        console.error(`[Cleanup] Error during cleanup:`, err);
    }
}

// Export for use in server.js or as a standalone script
module.exports = {
    performCleanup,
    init: (intervalMs = 60 * 60 * 1000) => { // Default to once per hour
        setInterval(performCleanup, intervalMs);
        console.log(`[Cleanup] Initialized with interval of ${intervalMs / 1000 / 60} minutes.`);
    }
};
