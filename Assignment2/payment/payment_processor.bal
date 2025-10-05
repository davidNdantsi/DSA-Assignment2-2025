// File: payment_processor.bal
// Payment Processing Logic

import ballerina/log;
import ballerina/random;
import ballerina/lang.runtime;

configurable int paymentSuccessRate = 95;  // 95% success rate
configurable int paymentProcessingDelayMs = 2000;  // 2 seconds

// ============================================
// PAYMENT PROCESSING
// ============================================

// Process payment (simulates real payment gateway)
public function processPayment(PaymentRequest request) returns PaymentResponse|error {
    log:printInfo("Processing payment for ticket: " + request.ticketId);
    
    // Generate payment ID
    string paymentId = generatePaymentId();
    string currentTime = getCurrentTimestamp();
    
    // Create payment record with PENDING status
    Payment payment = {
        paymentId: paymentId,
        ticketId: request.ticketId,
        passengerId: request.passengerId,
        amount: request.amount,
        currency: request.currency ?: "NAD",
        status: PENDING,
        paymentMethod: request.paymentMethod ?: MOBILE_MONEY,
        transactionReference: (),
        failureReason: (),
        transactionDate: currentTime,
        createdAt: currentTime,
        updatedAt: currentTime
    };
    
    // Store payment in database
    check insertPayment(payment);
    
    // ✅ SIMULATE PAYMENT PROCESSING DELAY
    log:printInfo("Simulating payment processing (waiting " + paymentProcessingDelayMs.toString() + "ms)...");
    runtime:sleep(<decimal>paymentProcessingDelayMs / 1000.0);
    
    // ✅ SIMULATE SUCCESS/FAILURE (based on configured success rate)
    boolean isSuccess = simulatePaymentResult();
    
    if isSuccess {
        // Payment successful
        string transactionRef = generateTransactionReference();
        check updatePaymentStatus(paymentId, SUCCESS, transactionReference = transactionRef);
        
        log:printInfo("Payment successful: " + paymentId);
        
        return {
            paymentId: paymentId,
            ticketId: request.ticketId,
            status: SUCCESS,
            transactionReference: transactionRef,
            failureReason: (),
            transactionDate: currentTime
        };
    } else {
        // Payment failed
        string failureReason = generateFailureReason();
        check updatePaymentStatus(paymentId, FAILED, failureReason = failureReason);
        
        log:printWarn("Payment failed: " + paymentId + " - " + failureReason);
        
        return {
            paymentId: paymentId,
            ticketId: request.ticketId,
            status: FAILED,
            transactionReference: (),
            failureReason: failureReason,
            transactionDate: currentTime
        };
    }
}

// Simulate payment result based on success rate
function simulatePaymentResult() returns boolean {
    float randomValue = random:createDecimal() * 100.0;
    return randomValue < <float>paymentSuccessRate;
}

// Generate random failure reason
function generateFailureReason() returns string {
    string[] reasons = [
        "Insufficient funds",
        "Card declined",
        "Payment gateway timeout",
        "Invalid card details",
        "Transaction limit exceeded"
    ];
    
    int index = <int>(random:createDecimal() * <float>reasons.length());
    return reasons[index];
}