// File: types.bal
// Type Definitions for Notification Service



// ============================================
// NOTIFICATION TYPES
// ============================================

public enum NotificationType {
    TICKET_PURCHASED = "TICKET_PURCHASED",
    TICKET_VALIDATED = "TICKET_VALIDATED",
    SCHEDULE_UPDATE = "SCHEDULE_UPDATE",
    TRIP_DELAYED = "TRIP_DELAYED",
    TRIP_CANCELLED = "TRIP_CANCELLED",
    PAYMENT_SUCCESS = "PAYMENT_SUCCESS",
    PAYMENT_FAILED = "PAYMENT_FAILED"
}

public enum NotificationChannel {
    EMAIL = "EMAIL",
    SMS = "SMS",
    PUSH = "PUSH",
    CONSOLE = "CONSOLE"
}

public enum NotificationStatus {
    PENDING = "PENDING",
    SENT = "SENT",
    DELIVERED = "DELIVERED",
    FAILED = "FAILED"
}

public enum DisruptionSeverity {
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    CRITICAL = "CRITICAL"
}

// ============================================
// CORE TYPES
// ============================================

public type Notification record {|
    string notificationId;
    string passengerId;
    NotificationType notificationType;
    NotificationChannel channel;
    string subject;
    string message;
    NotificationStatus status;
    string? errorMessage = ();
    string createdAt;
    string? sentAt = ();
    map<json> metadata = {};
|};

// ============================================
// KAFKA MESSAGE TYPES
// ============================================

// Schedule Update Message (from Admin Service)
public type ScheduleUpdateMessage record {|
    string disruptionId;
    string title;
    string description;
    DisruptionSeverity severity;
    string[] affectedRoutes;
    string startTime;
    string? endTime = ();
    string createdAt;
|};

// Ticket Validated Message (from Ticketing Service)
public type TicketValidatedMessage record {|
    string validationId;
    string ticketId;
    string passengerId;
    string tripId;
    string routeId;
    string validatedAt;
    string validatedBy;
    string location;
|};

// Ticket Created Message (from Ticketing Service)
public type TicketCreatedMessage record {|
    string ticketId;
    string passengerId;
    string tripId;
    string routeId;
    string routeName;
    decimal price;
    string scheduledDeparture;
    string qrCode;
    string createdAt;
|};

// ============================================
// DATABASE PROJECTION TYPES
// ============================================

public type NotificationRecord record {|
    string notificationId;
    string passengerId;
    string 'type;  // Store as string in MongoDB
    string channel;
    string subject;
    string message;
    string status;
    string? errorMessage;
    string createdAt;
    string? sentAt;
    map<json> metadata;
|};