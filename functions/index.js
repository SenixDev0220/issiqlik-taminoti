'use strict';
// Spark release intentionally exports no deployable triggers.
// Removed the plaintext password queue and shared-topic push sender.
// IMPORTANT: changing this source does NOT remove already deployed Functions.
// An authorized operator must inventory and disable/remove applyPasswordReset
// and sendNotificationPush before enabling the migrated client/rules. Do not
// deploy Functions or upgrade billing as part of this Spark release.
module.exports = Object.freeze({});
