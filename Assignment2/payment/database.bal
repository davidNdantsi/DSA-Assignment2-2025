// File: database.bal
// MongoDB Database Operations

import ballerinax/mongodb;
import ballerina/log;

configurable string mongoHost = ?;
configurable int mongoPort = ?;
configurable string mongoDatabase = ?;

// MongoDB client
final mongodb:Client mongoClient = check new ({
    connection: string `mongodb://${mongoHost}:${mongoPort}`
});

// Get payments collection
function getPaymentsCollection() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase(mongoDatabase);
    return db->getCollection("payments");
}

// ============================================
// PAYMENT CRUD OPERATIONS
// ============================================

// Insert new payment
public function insertPayment(Payment payment) returns error? {
    mongodb:Collection paymentsCollection = check getPaymentsCollection();
    check paymentsCollection->insertOne(payment);
    log:printInfo("Payment created: " + payment.paymentId);
}

// Find payment by ID
public function findPaymentById(string paymentId) returns Payment|error? {
    mongodb:Collection paymentsCollection = check getPaymentsCollection();
    
    map<json> filter = {
        "paymentId": paymentId
    };
    
    stream<Payment, error?> result = check paymentsCollection->find(filter);
    
    Payment[] payments = check from Payment p in result select p;
    
    if payments.length() == 0 {
        return ();
    }
    
    return payments[0];
}

// Find payment by ticket ID
public function findPaymentByTicketId(string ticketId) returns Payment|error? {
    mongodb:Collection paymentsCollection = check getPaymentsCollection();
    
    map<json> filter = {
        "ticketId": ticketId
    };
    
    stream<Payment, error?> result = check paymentsCollection->find(filter);
    
    Payment[] payments = check from Payment p in result select p;
    
    if payments.length() == 0 {
        return ();
    }
    
    return payments[0];
}

// Find payments by passenger ID
public function findPaymentsByPassengerId(string passengerId, PaymentStatus? status = ()) returns Payment[]|error {
    mongodb:Collection paymentsCollection = check getPaymentsCollection();
    
    map<json> filter = {
        "passengerId": passengerId
    };
    
    if status is PaymentStatus {
        filter["status"] = status.toString();
    }
    
    stream<Payment, error?> result = check paymentsCollection->find(filter);
    
    return from Payment p in result select p;
}

// Find all payments
public function findAllPayments(PaymentStatus? status = ()) returns Payment[]|error {
    mongodb:Collection paymentsCollection = check getPaymentsCollection();
    
    map<json> filter = {};
    
    if status is PaymentStatus {
        filter["status"] = status.toString();
    }
    
    stream<Payment, error?> result = check paymentsCollection->find(filter);
    
    return from Payment p in result select p;
}

// Update payment status
public function updatePaymentStatus(
    string paymentId,
    PaymentStatus status,
    string? transactionReference = (),
    string? failureReason = ()
) returns error? {
    mongodb:Collection paymentsCollection = check getPaymentsCollection();
    
    map<json> filter = {
        "paymentId": paymentId
    };
    
    // Build the $set document with base fields
    map<json> setFields = {
        "status": status.toString(),
        "updatedAt": getCurrentTimestamp()
    };
    
    // Add optional fields if provided
    if transactionReference is string {
        setFields["transactionReference"] = transactionReference;
    }
    
    if failureReason is string {
        setFields["failureReason"] = failureReason;
    }
    
    // Create the update document as mongodb:Update type
    mongodb:Update update = {
        set: setFields
    };
    
    mongodb:UpdateResult updateResult = check paymentsCollection->updateOne(filter, update);
    
    if updateResult.modifiedCount == 0 {
        return error("Payment not found: " + paymentId);
    }
    
    log:printInfo("Payment status updated: " + paymentId + " -> " + status.toString());
}

// Delete payment (admin only)
public function deletePayment(string paymentId) returns error? {
    mongodb:Collection paymentsCollection = check getPaymentsCollection();
    
    map<json> filter = {
        "paymentId": paymentId
    };
    
    mongodb:DeleteResult deleteResult = check paymentsCollection->deleteOne(filter);
    
    if deleteResult.deletedCount == 0 {
        return error("Payment not found: " + paymentId);
    }
    
    log:printInfo("Payment deleted: " + paymentId);
}

// Get payment statistics
public function getPaymentStats() returns map<json>|error {
    mongodb:Collection paymentsCollection = check getPaymentsCollection();
    
    stream<Payment, error?> allPayments = check paymentsCollection->find({});
    Payment[] payments = check from Payment p in allPayments select p;
    
    int totalPayments = payments.length();
    int successfulPayments = 0;
    int failedPayments = 0;
    int pendingPayments = 0;
    decimal totalAmount = 0.0;
    
    foreach Payment payment in payments {
        if payment.status == SUCCESS {
            successfulPayments += 1;
            totalAmount += payment.amount;
        } else if payment.status == FAILED {
            failedPayments += 1;
        } else if payment.status == PENDING {
            pendingPayments += 1;
        }
    }
    
    return {
        "totalPayments": totalPayments,
        "successful": successfulPayments,
        "failed": failedPayments,
        "pending": pendingPayments,
        "totalAmountProcessed": totalAmount.toString(),
        "successRate": totalPayments > 0 ? (successfulPayments * 100.0 / totalPayments).toString() + "%" : "0%"
    };
}