// File: utils.bal
// Utility Functions

import ballerina/time;
import ballerina/uuid;
import ballerina/log;

// ============================================
// ID GENERATION
// ============================================

// Generate unique payment ID
public function generatePaymentId() returns string {
    string uuid = uuid:createType1AsString();
    return "PAY-" + uuid.substring(0, 8).toUpperAscii();
}

// Generate transaction reference
public function generateTransactionReference() returns string {
    string uuid = uuid:createType1AsString();
    return "TXN-" + uuid.substring(0, 12).toUpperAscii();
}

// ============================================
// TIMESTAMP UTILITIES
// ============================================

// Get current timestamp in ISO 8601 format
public function getCurrentTimestamp() returns string {
    time:Utc currentTime = time:utcNow();
    return time:utcToString(currentTime);
}

// ============================================
// RESPONSE HELPERS
// ============================================

// Create success response
public function createSuccessResponse(string message, json? data = ()) returns ApiResponse {
    return {
        success: true,
        message: message,
        data: data,
        timestamp: getCurrentTimestamp()
    };
}

// Create error response
public function createErrorResponse(string message, string? errorCode = ()) returns ErrorResponse {
    return {
        success: false,
        message: message,
        errorCode: errorCode,
        timestamp: getCurrentTimestamp()
    };
}

// ============================================
// LOGGING HELPERS
// ============================================

// Log info message
public function logInfo(string message) {
    log:printInfo(message);
}

// Log error with details
public function logError(string message, error err) {
    log:printError(message, 'error = err);
}