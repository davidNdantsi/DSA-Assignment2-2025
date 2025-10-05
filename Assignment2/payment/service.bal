// File: service.bal
// Payment Service HTTP API (Temporary - will be replaced by Kafka)

import ballerina/http;
import ballerina/log;

configurable int servicePort = ?;
configurable string serviceHost = ?;

// HTTP listener configuration
listener http:Listener httpListener = new (servicePort, config = {
    host: serviceHost
});

// ============================================
// PAYMENT SERVICE
// ============================================

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allowHeaders: ["Content-Type", "Authorization"],
        maxAge: 3600
    }
}
service /payment on httpListener {

    // Health check endpoint
    resource function get health() returns json {
        return {
            status: "UP",
            serviceName: "Payment Service",
            timestamp: getCurrentTimestamp()
        };
    }

    // ============================================
    // PAYMENT ENDPOINTS (Temporary REST API)
    // ============================================

    // Process payment (will be replaced by Kafka consumer)
    resource function post payments(@http:Payload PaymentRequest request) returns http:Created|http:BadRequest|http:InternalServerError {
        log:printInfo("Payment request received for ticket: " + request.ticketId);
        
        // Validate amount (convert int to decimal for comparison)
        if request.amount <= 0.0d {
            ErrorResponse errorResp = createErrorResponse("Invalid payment amount", "INVALID_AMOUNT");
            return <http:BadRequest>{ body: errorResp };
        }
        
        // Check if payment already exists for this ticket
        Payment|error? existingPayment = findPaymentByTicketId(request.ticketId);
        
        if existingPayment is error {
            logError("Error checking existing payment", existingPayment);
            ErrorResponse errorResp = createErrorResponse("Database error");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if existingPayment is Payment {
            ErrorResponse errorResp = createErrorResponse(
                "Payment already exists for this ticket",
                "DUPLICATE_PAYMENT"
            );
            return <http:BadRequest>{ body: errorResp };
        }
        
        // Process payment
        PaymentResponse|error paymentResult = processPayment(request);
        
        if paymentResult is error {
            logError("Payment processing failed", paymentResult);
            ErrorResponse errorResp = createErrorResponse("Payment processing failed");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        // TODO: Publish to Kafka payments.processed topic
        logInfo("Payment processed (Kafka event would be published here): " + paymentResult.paymentId);
        
        ApiResponse response = createSuccessResponse(
            paymentResult.status == SUCCESS ? "Payment successful" : "Payment failed",
            paymentResult.toJson()
        );
        
        return <http:Created>{ body: response };
    }

    // Get payment by ID
    resource function get payments/[string paymentId]() returns http:Ok|http:NotFound|http:InternalServerError {
        log:printInfo("Fetching payment: " + paymentId);
        
        Payment|error? payment = findPaymentById(paymentId);
        
        if payment is error {
            logError("Error fetching payment", payment);
            ErrorResponse errorResp = createErrorResponse("Error fetching payment");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if payment is () {
            ErrorResponse errorResp = createErrorResponse("Payment not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Payment fetched successfully", payment.toJson());
        return <http:Ok>{ body: response };
    }

    // Get payment by ticket ID
    resource function get payments/ticket/[string ticketId]() returns http:Ok|http:NotFound|http:InternalServerError {
        log:printInfo("Fetching payment for ticket: " + ticketId);
        
        Payment|error? payment = findPaymentByTicketId(ticketId);
        
        if payment is error {
            logError("Error fetching payment", payment);
            ErrorResponse errorResp = createErrorResponse("Error fetching payment");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if payment is () {
            ErrorResponse errorResp = createErrorResponse("Payment not found for this ticket");
            return <http:NotFound>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Payment fetched successfully", payment.toJson());
        return <http:Ok>{ body: response };
    }

    // Get all payments for a passenger
    resource function get payments(string? passengerId = (), string? status = ()) returns http:Ok|http:InternalServerError {
        log:printInfo("Fetching payments");
        
        Payment[]|error payments;
        PaymentStatus? paymentStatus = ();
        
        // Parse status if provided
        if status is string {
            if status == "PENDING" {
                paymentStatus = PENDING;
            } else if status == "SUCCESS" {
                paymentStatus = SUCCESS;
            } else if status == "FAILED" {
                paymentStatus = FAILED;
            } else if status == "REFUNDED" {
                paymentStatus = REFUNDED;
            }
        }
        
        if passengerId is string {
            payments = findPaymentsByPassengerId(passengerId, paymentStatus);
        } else {
            payments = findAllPayments(paymentStatus);
        }
        
        if payments is error {
            logError("Failed to fetch payments", payments);
            ErrorResponse errorResp = createErrorResponse("Failed to fetch payments");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Payments fetched successfully", payments.toJson());
        return <http:Ok>{ body: response };
    }

    // Get payment statistics (admin endpoint)
    resource function get payments/stats() returns http:Ok|http:InternalServerError {
        log:printInfo("Fetching payment statistics");
        
        map<json>|error stats = getPaymentStats();
        
        if stats is error {
            logError("Failed to fetch payment statistics", stats);
            ErrorResponse errorResp = createErrorResponse("Failed to fetch payment statistics");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Payment statistics fetched successfully", stats);
        return <http:Ok>{ body: response };
    }

    // Refund payment (admin only)
    resource function post payments/[string paymentId]/refund() returns http:Ok|http:NotFound|http:BadRequest|http:InternalServerError {
        log:printInfo("Processing refund for payment: " + paymentId);
        
        // Fetch payment
        Payment|error? existingPayment = findPaymentById(paymentId);
        
        if existingPayment is error {
            logError("Error fetching payment", existingPayment);
            ErrorResponse errorResp = createErrorResponse("Database error");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if existingPayment is () {
            ErrorResponse errorResp = createErrorResponse("Payment not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        // Check if payment can be refunded
        if existingPayment.status != SUCCESS {
            ErrorResponse errorResp = createErrorResponse(
                "Only successful payments can be refunded. Current status: " + existingPayment.status.toString(),
                "INVALID_STATUS"
            );
            return <http:BadRequest>{ body: errorResp };
        }
        
        // Update payment status to REFUNDED
        error? updateResult = updatePaymentStatus(paymentId, REFUNDED);
        
        if updateResult is error {
            logError("Failed to process refund", updateResult);
            ErrorResponse errorResp = createErrorResponse("Failed to process refund");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        logInfo("Payment refunded: " + paymentId);
        
        // Fetch updated payment
        Payment|error? updatedPayment = findPaymentById(paymentId);
        
        if updatedPayment is error {
            logError("Error fetching updated payment", updatedPayment);
            ErrorResponse errorResp = createErrorResponse("Error fetching updated payment");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if updatedPayment is () {
            ErrorResponse errorResp = createErrorResponse("Updated payment not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Payment refunded successfully", updatedPayment.toJson());
        return <http:Ok>{ body: response };
    }

    // Delete payment (admin only)
    resource function delete payments/[string paymentId]() returns http:Ok|http:NotFound|http:InternalServerError {
        log:printInfo("Deleting payment: " + paymentId);
        
        error? deleteResult = deletePayment(paymentId);
        
        if deleteResult is error {
            if deleteResult.message().includes("not found") {
                ErrorResponse errorResp = createErrorResponse("Payment not found");
                return <http:NotFound>{ body: errorResp };
            }
            
            logError("Failed to delete payment", deleteResult);
            ErrorResponse errorResp = createErrorResponse("Failed to delete payment");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Payment deleted successfully");
        return <http:Ok>{ body: response };
    }
}