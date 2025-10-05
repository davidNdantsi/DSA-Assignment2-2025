// File: utils.bal
// Utility functions for Ticketing Service

import ballerina/time;
import ballerina/uuid;
import ballerina/log;
import ballerina/crypto;

configurable int ticketValidityHours = 24;

// Generate unique ticket ID
public function generateTicketId() returns string {
    return "TKT" + uuid:createType1AsString().substring(0, 10).toUpperAscii();
}

// Generate QR code (simplified - just a unique hash)
public function generateQRCode(string ticketId, string passengerId) returns string {
    string data = ticketId + passengerId + getCurrentTimestamp();
    byte[] hash = crypto:hashSha256(data.toBytes());
    return hash.toBase64();
}

// Get current timestamp in ISO 8601 format
public function getCurrentTimestamp() returns string {
    time:Utc currentTime = time:utcNow();
    return time:utcToString(currentTime);
}

// Calculate ticket expiration time
public function calculateExpirationTime(string purchaseTime) returns string|error {
    time:Utc purchaseUtc = check time:utcFromString(purchaseTime);
    time:Utc expirationUtc = time:utcAddSeconds(purchaseUtc, <decimal>(ticketValidityHours * 3600));
    return time:utcToString(expirationUtc);
}

// Check if ticket is expired
public function isTicketExpired(string validUntil) returns boolean|error {
    time:Utc expirationTime = check time:utcFromString(validUntil);
    time:Utc currentTime = time:utcNow();
    
    return time:utcDiffSeconds(currentTime, expirationTime) > 0d;
}

// Create success response
public function createSuccessResponse(string message, json? data = ()) returns ApiResponse {
    return {
        success: true,
        message: message,
        data: data
    };
}

// Create error response
public function createErrorResponse(string message, string? errorCode = ()) returns ErrorResponse {
    return {
        success: false,
        message: message,
        errorCode: errorCode
    };
}

// Log error with details
public function logError(string message, error err) {
    log:printError(message, 'error = err);
}

// Log info
public function logInfo(string message) {
    log:printInfo(message);
}