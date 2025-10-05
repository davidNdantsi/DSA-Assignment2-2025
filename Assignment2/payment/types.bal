// File: types.bal
// Payment Service Data Types



// ============================================
// ENUMS
// ============================================

// Payment status
public enum PaymentStatus {
    PENDING,
    SUCCESS,
    FAILED,
    REFUNDED
}

// Payment method
public enum PaymentMethod {
    CREDIT_CARD,
    DEBIT_CARD,
    MOBILE_MONEY,
    CASH,
    BANK_TRANSFER
}

// ============================================
// PAYMENT RECORDS
// ============================================

// Payment record stored in database
public type Payment record {|
    string paymentId;
    string ticketId;
    string passengerId;
    decimal amount;
    string currency;
    PaymentStatus status;
    PaymentMethod paymentMethod;
    string? transactionReference;  // External payment gateway reference
    string? failureReason;  // Reason if payment failed
    string transactionDate;
    string createdAt;
    string updatedAt;
|};

// ============================================
// REQUEST/RESPONSE TYPES
// ============================================

// Payment request (temporary REST API - will be replaced by Kafka)
public type PaymentRequest record {|
    string ticketId;
    string passengerId;
    decimal amount;
    string currency?;  // Default: "NAD"
    PaymentMethod paymentMethod?;  // Default: MOBILE_MONEY
|};

// Payment response
public type PaymentResponse record {|
    string paymentId;
    string ticketId;
    PaymentStatus status;
    string? transactionReference;
    string? failureReason;
    string transactionDate;
|};

// ============================================
// API RESPONSE WRAPPER
// ============================================

public type ApiResponse record {|
    boolean success;
    string message;
    json data?;
    string timestamp;
|};

public type ErrorResponse record {|
    boolean success = false;
    string message;
    string errorCode?;
    string timestamp;
|};