// File: service.bal
// Ticketing Service HTTP API

import ballerina/http;
import ballerina/log;

configurable int servicePort = ?;
configurable string serviceHost = ?;

// HTTP listener configuration
listener http:Listener httpListener = new (servicePort, config = {
    host: serviceHost
});

// ============================================
// HTTP CLIENTS FOR DEPENDENT SERVICES
// ============================================

// HTTP client for Passenger Service
final http:Client passengerClient = check new ("http://localhost:9090");

// HTTP client for Transport Service
final http:Client transportClient = check new ("http://localhost:9091");

// ============================================
// TICKETING SERVICE
// ============================================

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allowHeaders: ["Content-Type", "Authorization"],
        maxAge: 3600
    }
}
service /ticketing on httpListener {

    // Health check endpoint
    resource function get health() returns json {
        return {
            status: "UP",
            serviceName: "Ticketing Service",
            timestamp: getCurrentTimestamp()
        };
    }

    // ============================================
    // TICKET MANAGEMENT ENDPOINTS
    // ============================================

    // Purchase a new ticket
    resource function post tickets(@http:Payload TicketPurchaseRequest request) returns http:Created|http:BadRequest|http:InternalServerError {
        log:printInfo("Processing ticket purchase for passenger: " + request.passengerId);
        
        // ✅ STEP 1: Validate passenger exists
        PassengerInfo|error? passengerInfo = getPassengerFromPassengerService(request.passengerId);
        
        if passengerInfo is error {
            logError("Error fetching passenger info", passengerInfo);
            ErrorResponse errorResp = createErrorResponse("Failed to fetch passenger information");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if passengerInfo is () {
            ErrorResponse errorResp = createErrorResponse("Passenger not found", "PASSENGER_NOT_FOUND");
            return <http:BadRequest>{ body: errorResp };
        }
        
        // Check if passenger account is active
        if passengerInfo.status != "ACTIVE" {
            ErrorResponse errorResp = createErrorResponse(
                "Passenger account is not active. Status: " + passengerInfo.status,
                "INACTIVE_PASSENGER"
            );
            return <http:BadRequest>{ body: errorResp };
        }
        
        // ✅ STEP 2: Validate trip exists and has available seats
        TripInfo|error? tripInfo = getTripFromTransportService(request.tripId);
        
        if tripInfo is error {
            logError("Error fetching trip info", tripInfo);
            ErrorResponse errorResp = createErrorResponse("Failed to fetch trip information");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if tripInfo is () {
            ErrorResponse errorResp = createErrorResponse("Trip not found", "TRIP_NOT_FOUND");
            return <http:BadRequest>{ body: errorResp };
        }
        
        // Check if trip has available seats
        if tripInfo.availableSeats <= 0 {
            ErrorResponse errorResp = createErrorResponse("No available seats for this trip", "NO_SEATS");
            return <http:BadRequest>{ body: errorResp };
        }
        
        // Check if trip is in valid status
        if tripInfo.status != "SCHEDULED" {
            ErrorResponse errorResp = createErrorResponse("Trip is not available for booking", "INVALID_TRIP_STATUS");
            return <http:BadRequest>{ body: errorResp };
        }
        
        // ✅ STEP 3: Generate ticket
        string currentTime = getCurrentTimestamp();
        string ticketId = generateTicketId();
        string qrCode = generateQRCode(ticketId, request.passengerId);
        
        string|error expirationTime = calculateExpirationTime(currentTime);
        if expirationTime is error {
            logError("Error calculating expiration time", expirationTime);
            ErrorResponse errorResp = createErrorResponse("Error processing ticket");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        Ticket newTicket = {
            ticketId: ticketId,
            passengerId: request.passengerId,
            tripId: request.tripId,
            routeId: tripInfo.routeId,
            routeNumber: tripInfo.routeNumber,
            fare: tripInfo.fare,
            status: CREATED,
            qrCode: qrCode,
            purchasedAt: currentTime,
            validatedAt: (),
            validUntil: expirationTime,
            paymentId: (),
            createdAt: currentTime,
            updatedAt: currentTime
        };
        
        // Insert ticket into database
        error? insertResult = insertTicket(newTicket);
        
        if insertResult is error {
            logError("Failed to create ticket", insertResult);
            ErrorResponse errorResp = createErrorResponse("Failed to create ticket");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        // TODO: Publish to Kafka ticket.requests topic
        logInfo("Ticket created (Kafka event would be published here): " + ticketId);
        
        ApiResponse response = createSuccessResponse("Ticket created successfully. Awaiting payment.", newTicket.toJson());
        return <http:Created>{ body: response };
    }

    // Get ticket by ID
    resource function get tickets/[string ticketId]() returns http:Ok|http:NotFound|http:InternalServerError {
        log:printInfo("Fetching ticket: " + ticketId);
        
        Ticket|error? ticket = findTicketById(ticketId);
        
        if ticket is error {
            logError("Error fetching ticket", ticket);
            ErrorResponse errorResp = createErrorResponse("Error fetching ticket");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if ticket is () {
            ErrorResponse errorResp = createErrorResponse("Ticket not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Ticket fetched successfully", ticket.toJson());
        return <http:Ok>{ body: response };
    }

    // Get all tickets for a passenger
    resource function get tickets(string? passengerId = (), TicketStatus? status = ()) returns http:Ok|http:BadRequest|http:InternalServerError {
        log:printInfo("Fetching tickets");
        
        Ticket[]|error tickets;
        
        if passengerId is string {
            tickets = findTicketsByPassengerId(passengerId, status);
        } else {
            tickets = findAllTickets(status);
        }
        
        if tickets is error {
            logError("Failed to fetch tickets", tickets);
            ErrorResponse errorResp = createErrorResponse("Failed to fetch tickets");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Tickets fetched successfully", tickets.toJson());
        return <http:Ok>{ body: response };
    }

    // Validate ticket (mark as used)
    resource function put tickets/[string ticketId]/validate(@http:Payload TicketValidationRequest request) returns http:Ok|http:NotFound|http:BadRequest|http:InternalServerError {
        log:printInfo("Validating ticket: " + ticketId);
        
        // Fetch ticket
        Ticket|error? existingTicket = findTicketById(ticketId);
        
        if existingTicket is error {
            logError("Error checking ticket", existingTicket);
            ErrorResponse errorResp = createErrorResponse("Database error");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if existingTicket is () {
            ErrorResponse errorResp = createErrorResponse("Ticket not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        // Check if ticket is PAID
        if existingTicket.status != PAID {
            ErrorResponse errorResp = createErrorResponse(
                "Ticket cannot be validated. Status: " + existingTicket.status.toString(),
                "INVALID_TICKET_STATUS"
            );
            return <http:BadRequest>{ body: errorResp };
        }
        
        // Check if ticket is expired
        boolean|error expired = isTicketExpired(existingTicket.validUntil);
        
        if expired is error {
            logError("Error checking expiration", expired);
            ErrorResponse errorResp = createErrorResponse("Error validating ticket");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if expired {
            // Update ticket status to EXPIRED
            error? expireResult = updateTicketStatus(ticketId, EXPIRED);
            
            if expireResult is error {
                logError("Failed to update expired ticket", expireResult);
            }
            
            ErrorResponse errorResp = createErrorResponse("Ticket has expired", "TICKET_EXPIRED");
            return <http:BadRequest>{ body: errorResp };
        }
        
        // Mark ticket as VALIDATED
        string validatedAt = getCurrentTimestamp();
        error? updateResult = updateTicketStatus(ticketId, VALIDATED, validatedAt = validatedAt);
        
        if updateResult is error {
            logError("Failed to validate ticket", updateResult);
            ErrorResponse errorResp = createErrorResponse("Failed to validate ticket");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        logInfo("Ticket validated: " + ticketId + " by " + request.validatedBy);
        
        // Fetch updated ticket
        Ticket|error? updatedTicket = findTicketById(ticketId);
        
        if updatedTicket is error {
            logError("Error fetching updated ticket", updatedTicket);
            ErrorResponse errorResp = createErrorResponse("Error fetching updated ticket");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if updatedTicket is () {
            ErrorResponse errorResp = createErrorResponse("Updated ticket not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Ticket validated successfully", updatedTicket.toJson());
        return <http:Ok>{ body: response };
    }

    // Manual payment confirmation (simulates Kafka event)
    resource function post tickets/[string ticketId]/confirm\-payment(@http:Payload json paymentData) returns http:Ok|http:NotFound|http:BadRequest|http:InternalServerError {
        log:printInfo("Confirming payment for ticket: " + ticketId);
        
        // Fetch ticket
        Ticket|error? existingTicket = findTicketById(ticketId);
        
        if existingTicket is error {
            logError("Error checking ticket", existingTicket);
            ErrorResponse errorResp = createErrorResponse("Database error");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if existingTicket is () {
            ErrorResponse errorResp = createErrorResponse("Ticket not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        // Check if ticket is CREATED
        if existingTicket.status != CREATED {
            ErrorResponse errorResp = createErrorResponse(
                "Ticket payment already processed. Status: " + existingTicket.status.toString(),
                "INVALID_TICKET_STATUS"
            );
            return <http:BadRequest>{ body: errorResp };
        }
        
        // Extract payment ID with explicit error handling
        json|error paymentIdResult = paymentData.paymentId;
        
        if paymentIdResult is error {
            logError("Invalid payment data", paymentIdResult);
            ErrorResponse errorResp = createErrorResponse("Invalid payment data");
            return <http:BadRequest>{ body: errorResp };
        }
        
        string? paymentId = paymentIdResult.toString();
        
        // Update ticket status to PAID
        error? updateResult = updateTicketStatus(ticketId, PAID, paymentId = paymentId);
        
        if updateResult is error {
            logError("Failed to confirm payment", updateResult);
            ErrorResponse errorResp = createErrorResponse("Failed to confirm payment");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        logInfo("Payment confirmed for ticket: " + ticketId);
        
        // Fetch updated ticket
        Ticket|error? updatedTicket = findTicketById(ticketId);
        
        if updatedTicket is error {
            logError("Error fetching updated ticket", updatedTicket);
            ErrorResponse errorResp = createErrorResponse("Error fetching updated ticket");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if updatedTicket is () {
            ErrorResponse errorResp = createErrorResponse("Updated ticket not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Payment confirmed successfully", updatedTicket.toJson());
        return <http:Ok>{ body: response };
    }

    // Cleanup expired tickets (admin endpoint)
    resource function post tickets/cleanup\-expired() returns http:Ok|http:InternalServerError {
        log:printInfo("Running expired tickets cleanup");
        
        int|error expiredCount = updateExpiredTickets();
        
        if expiredCount is error {
            logError("Failed to cleanup expired tickets", expiredCount);
            ErrorResponse errorResp = createErrorResponse("Failed to cleanup expired tickets");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse(string `Expired ${expiredCount} tickets`, {expiredCount: expiredCount});
        return <http:Ok>{ body: response };
    }

    // Delete ticket (admin only)
    resource function delete tickets/[string ticketId]() returns http:Ok|http:NotFound|http:InternalServerError {
        log:printInfo("Deleting ticket: " + ticketId);
        
        error? deleteResult = deleteTicket(ticketId);
        
        if deleteResult is error {
            if deleteResult.message().includes("not found") {
                ErrorResponse errorResp = createErrorResponse("Ticket not found");
                return <http:NotFound>{ body: errorResp };
            }
            
            logError("Failed to delete ticket", deleteResult);
            ErrorResponse errorResp = createErrorResponse("Failed to delete ticket");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Ticket deleted successfully");
        return <http:Ok>{ body: response };
    }
}

// ============================================
// HELPER FUNCTIONS
// ============================================

// ✅ NEW: Fetch passenger information from Passenger Service
function getPassengerFromPassengerService(string passengerId) returns PassengerInfo|error? {
    http:Response response = check passengerClient->/passengers/[passengerId];
    
    if response.statusCode == 404 {
        return ();
    }
    
    if response.statusCode != 200 {
        return error("Passenger service returned status: " + response.statusCode.toString());
    }
    
    json payload = check response.getJsonPayload();
    json passengerData = check payload.data;
    
    return {
        passengerId: (check passengerData.passengerId).toString(),
        fullName: (check passengerData.fullName).toString(),
        email: (check passengerData.email).toString(),
        phoneNumber: (check passengerData.phoneNumber).toString(),
        status: (check passengerData.status).toString()
    };
}

// Fetch trip information from Transport Service
function getTripFromTransportService(string tripId) returns TripInfo|error? {
    http:Response response = check transportClient->/transport/trips/[tripId];
    
    if response.statusCode == 404 {
        return ();
    }
    
    if response.statusCode != 200 {
        return error("Transport service returned status: " + response.statusCode.toString());
    }
    
    json payload = check response.getJsonPayload();
    json tripData = check payload.data;
    
    return {
        tripId: (check tripData.tripId).toString(),
        routeId: (check tripData.routeId).toString(),
        routeNumber: (check tripData.routeNumber).toString(),
        fare: check decimal:fromString((check tripData.fare).toString()),
        departureTime: (check tripData.departureTime).toString(),
        arrivalTime: (check tripData.arrivalTime).toString(),
        availableSeats: check int:fromString((check tripData.availableSeats).toString()),
        status: (check tripData.status).toString()
    };
}