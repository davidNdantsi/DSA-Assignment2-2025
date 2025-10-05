// File: types.bal
// Data types for Ticketing Service



// Ticket Status
public enum TicketStatus {
    CREATED,    // Just requested
    PAID,       // Payment confirmed
    VALIDATED,  // Used on a vehicle
    EXPIRED     // No longer valid
}
public type PassengerInfo record {|
    string passengerId;
    string fullName;
    string email;
    string phoneNumber;
    string status;  // ACTIVE, INACTIVE, SUSPENDED
|};
// Ticket record
public type Ticket record {|
    string ticketId;
    string passengerId;
    string tripId;
    string routeId;
    string routeNumber;
    decimal fare;
    TicketStatus status;
    string qrCode;              // QR code for validation
    string purchasedAt;         // ISO 8601 timestamp
    string? validatedAt;        // When ticket was used
    string validUntil;          // Expiration time
    string? paymentId;          // Reference to payment
    string createdAt;
    string updatedAt;
|};

// Ticket purchase request
public type TicketPurchaseRequest record {|
    string passengerId;
    string tripId;
|};

// Ticket validation request
public type TicketValidationRequest record {|
    string vehicleId;
    string driverId;
    string validatedBy;         // Staff ID who validated
|};

// Trip info (from Transport Service)
public type TripInfo record {|
    string tripId;
    string routeId;
    string routeNumber;
    decimal fare;
    string departureTime;
    string arrivalTime;
    int availableSeats;
    string status;
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

// Kafka event types (for future implementation)
public type TicketRequestEvent record {|
    string ticketId;
    string passengerId;
    string tripId;
    decimal fare;
    string timestamp;
|};

public type PaymentProcessedEvent record {|
    string paymentId;
    string ticketId;
    string passengerId;
    decimal amount;
    string status;      // "SUCCESS" or "FAILED"
    string timestamp;
|};