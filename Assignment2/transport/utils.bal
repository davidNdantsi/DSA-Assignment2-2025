// File: utils.bal
// Utility functions for Transport Service

import ballerina/uuid;
import ballerina/regex;
import ballerina/time;
import ballerina/log;

// Generate unique route ID
public function generateRouteId() returns string {
    string uid = uuid:createType1AsString();
    string shortId = regex:replaceAll(uid, "-", "").substring(0, 10).toUpperAscii();
    return "R" + shortId;
}

// Generate unique trip ID
public function generateTripId() returns string {
    string uid = uuid:createType1AsString();
    string shortId = regex:replaceAll(uid, "-", "").substring(0, 10).toUpperAscii();
    return "T" + shortId;
}

// Get current ISO timestamp
public function getCurrentTimestamp() returns string {
    time:Utc currentTime = time:utcNow();
    return time:utcToString(currentTime);
}

// Calculate arrival time based on departure and duration
public function calculateArrivalTime(string departureTime, int durationMinutes) returns string|error {
    time:Utc departureUtc = check time:utcFromString(departureTime);
    time:Utc arrivalUtc = time:utcAddSeconds(departureUtc, <decimal>(durationMinutes * 60));
    return time:utcToString(arrivalUtc);
}

// Validate time format (ISO 8601)
public function isValidIsoTime(string timeString) returns boolean {
    time:Utc|error result = time:utcFromString(timeString);
    return result is time:Utc;
}

// Check if route number is valid format (e.g., "R001", "5", "A12")
public function isValidRouteNumber(string routeNumber) returns boolean {
    return routeNumber.length() > 0 && routeNumber.length() <= 10;
}

// Log info message
public function logInfo(string message) {
    log:printInfo(message);
}

// Log error message
public function logError(string message, error? err = ()) {
    if err is error {
        log:printError(message, 'error = err);
    } else {
        log:printError(message);
    }
}

// Log warning message
public function logWarning(string message) {
    log:printWarn(message);
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
// ============================================
// TRIP STATUS VALIDATION
// ============================================

public function isValidStatusTransition(TripStatus currentStatus, TripStatus newStatus) returns boolean {
    // Allow same status (idempotent updates)
    if currentStatus == newStatus {
        return true;
    }
    
    // Define valid transitions using if-else instead of match
    if currentStatus == SCHEDULED {
        // From SCHEDULED, can move to IN_PROGRESS, DELAYED, or CANCELLED
        return newStatus == IN_PROGRESS || newStatus == DELAYED || newStatus == CANCELLED;
    } else if currentStatus == IN_PROGRESS {
        // From IN_PROGRESS, can move to COMPLETED, DELAYED, or CANCELLED
        return newStatus == COMPLETED || newStatus == DELAYED || newStatus == CANCELLED;
    } else if currentStatus == DELAYED {
        // From DELAYED, can move to IN_PROGRESS or CANCELLED
        return newStatus == IN_PROGRESS || newStatus == CANCELLED;
    } else if currentStatus == COMPLETED {
        // Completed trips are final - no further transitions allowed
        return false;
    } else if currentStatus == CANCELLED {
        // Cancelled trips are final - no further transitions allowed
        return false;
    } 
}