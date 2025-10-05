// File: utils.bal
// Utility Functions

import ballerina/time;
import ballerina/log;

public function getCurrentTimestamp() returns string {
    time:Utc currentTime = time:utcNow();
    return time:utcToString(currentTime);
}

public function logInfo(string message) {
    log:printInfo(string `[NOTIFICATION-SERVICE] ${message}`);
}

public function logError(string message, error err) {
    log:printError(string `[NOTIFICATION-SERVICE] ${message}`, err);
}

public function logWarn(string message) {
    log:printWarn(string `[NOTIFICATION-SERVICE] ${message}`);
}