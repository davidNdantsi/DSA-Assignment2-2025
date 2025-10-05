// File: service.bal
// Transport Service HTTP API

import ballerina/http;
import ballerina/log;


configurable int servicePort = ?;
configurable string serviceHost = ?;

// HTTP listener configuration
listener http:Listener httpListener = new (servicePort, config = {
    host: serviceHost
});

// Transport Service
@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allowHeaders: ["Content-Type", "Authorization"],
        maxAge: 3600
    }
}
service /transport on httpListener {

    // Health check endpoint
    resource function get health() returns json {
        return {
            status: "UP",
            serviceName: "Transport Service",
            timestamp: getCurrentTimestamp()
        };
    }

    // ============================================
    // ROUTE MANAGEMENT ENDPOINTS
    // ============================================

    // Create a new route
    resource function post routes(@http:Payload RouteCreateRequest request) returns http:Created|http:BadRequest|http:InternalServerError {
        log:printInfo("Creating new route: " + request.routeNumber);
        
        // Validate input
        if !isValidRouteNumber(request.routeNumber) {
            ErrorResponse errorResp = createErrorResponse("Invalid route number format");
            return <http:BadRequest>{ body: errorResp };
        }
        
        // Check if route number already exists
        Route|error? existingRoute = findRouteByNumber(request.routeNumber);
        
        if existingRoute is Route {
            ErrorResponse errorResp = createErrorResponse("Route number already exists", "DUPLICATE_ROUTE");
            return <http:BadRequest>{ body: errorResp };
        }
        
        if existingRoute is error {
            logError("Error checking existing route", existingRoute);
            ErrorResponse errorResp = createErrorResponse("Database error");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        // Create new route
        string currentTime = getCurrentTimestamp();
        Route newRoute = {
            routeId: generateRouteId(),
            routeNumber: request.routeNumber,
            routeName: request.routeName,
            startLocation: request.startLocation,
            endLocation: request.endLocation,
            intermediateStops: request.intermediateStops,
            distance: request.distance,
            estimatedDuration: request.estimatedDuration,
            fare: request.fare,
            status: ACTIVE,
            createdAt: currentTime,
            updatedAt: currentTime
        };
        
        // Insert into database
        error? insertResult = insertRoute(newRoute);
        
        if insertResult is error {
            logError("Failed to create route", insertResult);
            ErrorResponse errorResp = createErrorResponse("Failed to create route");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Route created successfully", newRoute.toJson());
        return <http:Created>{ body: response };
    }

    // Get all routes
    resource function get routes(RouteStatus? status = ()) returns http:Ok|http:InternalServerError {
        log:printInfo("Fetching all routes");
        
        Route[]|error routes = findAllRoutes(status);
        
        if routes is error {
            logError("Failed to fetch routes", routes);
            ErrorResponse errorResp = createErrorResponse("Failed to fetch routes");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Routes fetched successfully", routes.toJson());
        return <http:Ok>{ body: response };
    }

    // Get route by ID
    resource function get routes/[string routeId]() returns http:Ok|http:NotFound|http:InternalServerError {
        log:printInfo("Fetching route: " + routeId);
        
        Route|error? route = findRouteById(routeId);
        
        if route is error {
            logError("Error fetching route", route);
            ErrorResponse errorResp = createErrorResponse("Error fetching route");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if route is () {
            ErrorResponse errorResp = createErrorResponse("Route not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Route fetched successfully", route.toJson());
        return <http:Ok>{ body: response };
    }

    // Update route
    resource function put routes/[string routeId](@http:Payload RouteUpdateRequest request) returns http:Ok|http:NotFound|http:InternalServerError {
        log:printInfo("Updating route: " + routeId);
        
        // Check if route exists
        Route|error? existingRoute = findRouteById(routeId);
        
        if existingRoute is error {
            logError("Error checking route", existingRoute);
            ErrorResponse errorResp = createErrorResponse("Database error");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if existingRoute is () {
            ErrorResponse errorResp = createErrorResponse("Route not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        // Build update map
        map<json> updates = {};
        
        if request.routeName is string {
            updates["routeName"] = request.routeName;
        }
        if request.startLocation is string {
            updates["startLocation"] = request.startLocation;
        }
        if request.endLocation is string {
            updates["endLocation"] = request.endLocation;
        }
        if request.intermediateStops is string[] {
            updates["intermediateStops"] = request.intermediateStops;
        }
        if request.distance is decimal {
            updates["distance"] = request.distance;
        }
        if request.estimatedDuration is int {
            updates["estimatedDuration"] = request.estimatedDuration;
        }
        if request.fare is decimal {
            updates["fare"] = request.fare;
        }
        if request.status is RouteStatus {
            updates["status"] = request.status;
        }
        
        // Update route
        error? updateResult = updateRoute(routeId, updates);
        
        if updateResult is error {
            logError("Failed to update route", updateResult);
            ErrorResponse errorResp = createErrorResponse(updateResult.message());
            return <http:InternalServerError>{ body: errorResp };
        }
        
        // Fetch updated route - FIX #1: Remove check, handle error explicitly
        Route|error? updatedRoute = findRouteById(routeId);
        
        if updatedRoute is error {
            logError("Error fetching updated route", updatedRoute);
            ErrorResponse errorResp = createErrorResponse("Error fetching updated route");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if updatedRoute is () {
            ErrorResponse errorResp = createErrorResponse("Updated route not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Route updated successfully", updatedRoute.toJson());
        return <http:Ok>{ body: response };
    }

    // Delete route
    resource function delete routes/[string routeId]() returns http:Ok|http:NotFound|http:InternalServerError {
        log:printInfo("Deleting route: " + routeId);
        
        error? deleteResult = deleteRoute(routeId);
        
        if deleteResult is error {
            if deleteResult.message().includes("not found") {
                ErrorResponse errorResp = createErrorResponse("Route not found");
                return <http:NotFound>{ body: errorResp };
            }
            
            logError("Failed to delete route", deleteResult);
            ErrorResponse errorResp = createErrorResponse("Failed to delete route");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Route deleted successfully");
        return <http:Ok>{ body: response };
    }
// ============================================
    // TRIP MANAGEMENT ENDPOINTS (WITH KAFKA)
    // ============================================

    // Create a new trip
    resource function post trips(@http:Payload TripCreateRequest request) returns http:Created|http:BadRequest|http:InternalServerError {
        log:printInfo("Creating new trip for route: " + request.routeId);
        
        // Validate departure time format
        if !isValidIsoTime(request.departureTime) {
            ErrorResponse errorResp = createErrorResponse("Invalid departure time format. Use ISO 8601 format");
            return <http:BadRequest>{ body: errorResp };
        }
        
        // Check if route exists
        Route|error? route = findRouteById(request.routeId);
        
        if route is error {
            logError("Error checking route", route);
            ErrorResponse errorResp = createErrorResponse("Database error");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if route is () {
            ErrorResponse errorResp = createErrorResponse("Route not found", "ROUTE_NOT_FOUND");
            return <http:BadRequest>{ body: errorResp };
        }
        
        // Calculate arrival time
        string|error arrivalTime = calculateArrivalTime(request.departureTime, route.estimatedDuration);
        
        if arrivalTime is error {
            logError("Error calculating arrival time", arrivalTime);
            ErrorResponse errorResp = createErrorResponse("Error calculating arrival time");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        // Create new trip
        string currentTime = getCurrentTimestamp();
        Trip newTrip = {
            tripId: generateTripId(),
            routeId: request.routeId,
            routeNumber: route.routeNumber,
            departureTime: request.departureTime,
            arrivalTime: arrivalTime,
            vehicleId: request.vehicleId,
            driverName: request.driverName,
            availableSeats: request.totalSeats,
            totalSeats: request.totalSeats,
            status: SCHEDULED,
            delayReason: (),
            delayMinutes: 0,
            createdAt: currentTime,
            updatedAt: currentTime
        };
        
        // Insert into database
        error? insertResult = insertTrip(newTrip);
        
        if insertResult is error {
            logError("Failed to create trip", insertResult);
            ErrorResponse errorResp = createErrorResponse("Failed to create trip");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Trip created successfully", newTrip.toJson());
        return <http:Created>{ body: response };
    }

    // Get all trips
    resource function get trips(string? routeId = (), TripStatus? status = ()) returns http:Ok|http:InternalServerError {
        log:printInfo("Fetching trips");
        
        Trip[]|error trips = findAllTrips(routeId, status);
        
        if trips is error {
            logError("Failed to fetch trips", trips);
            ErrorResponse errorResp = createErrorResponse("Failed to fetch trips");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Trips fetched successfully", trips.toJson());
        return <http:Ok>{ body: response };
    }

    // Get trip by ID
    resource function get trips/[string tripId]() returns http:Ok|http:NotFound|http:InternalServerError {
        log:printInfo("Fetching trip: " + tripId);
        
        Trip|error? trip = findTripById(tripId);
        
        if trip is error {
            logError("Error fetching trip", trip);
            ErrorResponse errorResp = createErrorResponse("Error fetching trip");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if trip is () {
            ErrorResponse errorResp = createErrorResponse("Trip not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Trip fetched successfully", trip.toJson());
        return <http:Ok>{ body: response };
    }

    // ============================================
    // UPDATE TRIP STATUS (WITH KAFKA INTEGRATION)
    // ============================================
    
    resource function put trips/[string tripId]/status(@http:Payload TripStatusUpdateRequest request) 
        returns http:Ok|http:NotFound|http:BadRequest|http:InternalServerError {
        
        log:printInfo("Updating trip status: " + tripId + " to " + request.status.toString());
        
        // Fetch existing trip
        Trip|error? existingTrip = findTripById(tripId);
        
        if existingTrip is error {
            logError("Error checking trip", existingTrip);
            ErrorResponse errorResp = createErrorResponse("Database error");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if existingTrip is () {
            ErrorResponse errorResp = createErrorResponse("Trip not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        // Store previous status for Kafka event
        TripStatus previousStatus = existingTrip.status;
        TripStatus newStatus = request.status;
        
        // Validate delay reason for DELAYED/CANCELLED status
        if (newStatus == DELAYED || newStatus == CANCELLED) && request.delayReason is () {
            ErrorResponse errorResp = createErrorResponse("Delay reason is required for DELAYED or CANCELLED status");
            return <http:BadRequest>{ body: errorResp };
        }
        
        // Validate status transition
        if !isValidStatusTransition(previousStatus, newStatus) {
            ErrorResponse errorResp = createErrorResponse(
                string `Invalid status transition from ${previousStatus} to ${newStatus}`,
                "INVALID_STATUS_TRANSITION"
            );
            return <http:BadRequest>{ body: errorResp };
        }
        
        int delayMinutes = request.delayMinutes ?: 0;
        
        // Update trip status in database
        error? updateResult = updateTripStatus(tripId, newStatus, request.delayReason, delayMinutes);
        
        if updateResult is error {
            logError("Failed to update trip status", updateResult);
            ErrorResponse errorResp = createErrorResponse(updateResult.message());
            return <http:InternalServerError>{ body: errorResp };
        }
        
        // Fetch updated trip
        Trip|error? updatedTrip = findTripById(tripId);
        
        if updatedTrip is error {
            logError("Error fetching updated trip", updatedTrip);
            ErrorResponse errorResp = createErrorResponse("Error fetching updated trip");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        if updatedTrip is () {
            ErrorResponse errorResp = createErrorResponse("Updated trip not found");
            return <http:NotFound>{ body: errorResp };
        }
        
        // ============================================
        // KAFKA INTEGRATION: Publish schedule update
        // ============================================
        
        // Only publish to Kafka if status actually changed
        if previousStatus != newStatus {
            
            // Determine event type based on new status
            ScheduleEventType eventType = SCHEDULE_CHANGE;
            
            if newStatus == DELAYED {
                eventType = DELAY;
            } else if newStatus == CANCELLED {
                eventType = CANCELLATION;
            }
            
            // Publish to Kafka (non-blocking - don't fail HTTP request if Kafka fails)
            KafkaPublishResult kafkaResult = publishScheduleUpdate(
                updatedTrip,
                previousStatus,
                eventType
            );
            
            if !kafkaResult.success {
                // Log warning but don't fail the request - DB update was successful
                log:printWarn(string `Trip ${tripId} updated in DB but Kafka publish failed: ${kafkaResult.errorMessage ?: "Unknown error"}`);
                log:printWarn("Schedule update will need to be republished or consumers should poll database");
            } else {
                log:printInfo(string `Successfully published ${eventType} event to Kafka for trip ${tripId}`);
                log:printInfo(string `Event details: ${previousStatus} -> ${newStatus}, Reason: ${request.delayReason ?: "N/A"}`);
            }
        } else {
            log:printInfo(string `Trip ${tripId} status unchanged (${previousStatus}), skipping Kafka publish`);
        }
        
        ApiResponse response = createSuccessResponse("Trip status updated successfully", updatedTrip.toJson());
        return <http:Ok>{ body: response };
    }

    // Delete trip
    resource function delete trips/[string tripId]() returns http:Ok|http:NotFound|http:InternalServerError {
        log:printInfo("Deleting trip: " + tripId);
        
        error? deleteResult = deleteTrip(tripId);
        
        if deleteResult is error {
            if deleteResult.message().includes("not found") {
                ErrorResponse errorResp = createErrorResponse("Trip not found");
                return <http:NotFound>{ body: errorResp };
            }
            
            logError("Failed to delete trip", deleteResult);
            ErrorResponse errorResp = createErrorResponse("Failed to delete trip");
            return <http:InternalServerError>{ body: errorResp };
        }
        
        ApiResponse response = createSuccessResponse("Trip deleted successfully");
        return <http:Ok>{ body: response };
    }

}