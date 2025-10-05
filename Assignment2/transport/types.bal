// File: types.bal
// Data types for Transport Service

// Route Status
public enum RouteStatus {
    ACTIVE,
    INACTIVE,
    SUSPENDED
}

// Trip Status
public enum TripStatus {
    SCHEDULED,
    IN_PROGRESS,
    COMPLETED,
    DELAYED,
    CANCELLED
}

// Route record
public type Route record {|
    string routeId;
    string routeNumber;
    string routeName;
    string startLocation;
    string endLocation;
    string[] intermediateStops;
    decimal distance; // in kilometers
    int estimatedDuration; // in minutes
    decimal fare;
    RouteStatus status;
    string createdAt;
    string updatedAt;
|};

// Trip record
public type Trip record {|
    string tripId;
    string routeId;
    string routeNumber;
    string departureTime; // ISO 8601 format
    string arrivalTime; // ISO 8601 format
    string vehicleId;
    string driverName;
    int availableSeats;
    int totalSeats;
    TripStatus status;
    string? delayReason;
    int delayMinutes;
    string createdAt;
    string updatedAt;
|};

// Route creation request
public type RouteCreateRequest record {|
    string routeNumber;
    string routeName;
    string startLocation;
    string endLocation;
    string[] intermediateStops;
    decimal distance;
    int estimatedDuration;
    decimal fare;
|};

// Route update request
public type RouteUpdateRequest record {|
    string? routeName;
    string? startLocation;
    string? endLocation;
    string[]? intermediateStops;
    decimal? distance;
    int? estimatedDuration;
    decimal? fare;
    RouteStatus? status;
|};

// Trip creation request
public type TripCreateRequest record {|
    string routeId;
    string departureTime;
    string vehicleId;
    string driverName;
    int totalSeats;
|};

// Trip status update request
public type TripStatusUpdateRequest record {|
    TripStatus status;
    string? delayReason;
    int? delayMinutes;
|};

// Standard API response
public type ApiResponse record {|
    boolean success;
    string message;
    json? data;
|};

// Error response
public type ErrorResponse record {|
    boolean success = false;
    string message;
    string? errorCode;
|};

// ============================================
// Kafka Message Types (NEW)
// ============================================

# Schedule event types
public enum ScheduleEventType {
    DELAY,
    CANCELLATION,
    SCHEDULE_CHANGE,
    ROUTE_UPDATE
}

# Represents a schedule update event published to Kafka
#
# + eventId - Unique event identifier
# + eventType - Type of event (DELAY, CANCELLATION, SCHEDULE_CHANGE)
# + tripId - ID of the affected trip
# + routeId - ID of the route
# + routeNumber - Route number for easy reference
# + previousStatus - Status before the change
# + newStatus - Status after the change
# + delayMinutes - Minutes of delay (if applicable)
# + reason - Reason for the change (optional)
# + timestamp - When the event occurred (ISO 8601)
public type ScheduleUpdateEvent record {|
    string eventId;
    ScheduleEventType eventType;
    string tripId;
    string routeId;
    string routeNumber;
    TripStatus previousStatus;
    TripStatus newStatus;
    int delayMinutes;
    string? reason;
    string timestamp;
|};

# Kafka producer response
public type KafkaPublishResult record {|
    boolean success;
    string? errorMessage;
|};