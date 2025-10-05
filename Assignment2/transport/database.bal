// File: database.bal
// MongoDB database configuration and operations

import ballerinax/mongodb;
import ballerina/log;

// MongoDB configuration
configurable string mongoHost = ?;
configurable int mongoPort = ?;
configurable string mongoDatabase = ?;

// Collection names
const string ROUTES_COLLECTION = "routes";
const string TRIPS_COLLECTION = "trips";

// MongoDB client instance (same pattern as passenger service)
mongodb:Client mongoClient = check new ({
    connection: string `mongodb://${mongoHost}:${mongoPort}`
});

// Get database
function getDatabase() returns mongodb:Database|error {
    return mongoClient->getDatabase(mongoDatabase);
}

// Get routes collection
public function getRoutesCollection() returns mongodb:Collection|error {
    mongodb:Database db = check getDatabase();
    return db->getCollection(ROUTES_COLLECTION);
}

// Get trips collection
public function getTripsCollection() returns mongodb:Collection|error {
    mongodb:Database db = check getDatabase();
    return db->getCollection(TRIPS_COLLECTION);
}

// Insert route
public function insertRoute(Route route) returns error? {
    mongodb:Collection collection = check getRoutesCollection();
    check collection->insertOne(route);
    log:printInfo("Route inserted: " + route.routeId);
}

// Find route by ID
public function findRouteById(string routeId) returns Route|error? {
    mongodb:Collection collection = check getRoutesCollection();
    map<json>? result = check collection->findOne({routeId: routeId});
    
    if result is () {
        return ();
    }
    
    return mapToRoute(result);
}

// Find route by route number
public function findRouteByNumber(string routeNumber) returns Route|error? {
    mongodb:Collection collection = check getRoutesCollection();
    map<json>? result = check collection->findOne({routeNumber: routeNumber});
    
    if result is () {
        return ();
    }
    
    return mapToRoute(result);
}

// Find all routes
public function findAllRoutes(RouteStatus? status = ()) returns Route[]|error {
    mongodb:Collection collection = check getRoutesCollection();
    
    map<json> filter = {};
    if status is RouteStatus {
        filter = {status: status};
    }
    
    stream<map<json>, error?> resultStream = check collection->find(filter);
    
    Route[] routes = [];
    check from map<json> doc in resultStream
        do {
            Route route = check mapToRoute(doc);
            routes.push(route);
        };
    
    return routes;
}

// Update route
public function updateRoute(string routeId, map<json> updates) returns error? {
    mongodb:Collection collection = check getRoutesCollection();
    
    // Add updatedAt timestamp
    map<json> mutableUpdates = updates.clone();
    mutableUpdates["updatedAt"] = getCurrentTimestamp();
    
    map<json> filter = {routeId: routeId};
    
    // Create proper update document for MongoDB 5.2.2
    mongodb:Update updateDoc = {
        set: mutableUpdates
    };
    
    mongodb:UpdateResult result = check collection->updateOne(filter, updateDoc);
    
    if result.modifiedCount == 0 {
        return error("Route not found or no changes made");
    }
    
    log:printInfo("Route updated: " + routeId);
}

// Delete route
public function deleteRoute(string routeId) returns error? {
    mongodb:Collection collection = check getRoutesCollection();
    map<json> filter = {routeId: routeId};
    mongodb:DeleteResult result = check collection->deleteOne(filter);
    
    if result.deletedCount == 0 {
        return error("Route not found");
    }
    
    log:printInfo("Route deleted: " + routeId);
}

// Insert trip
public function insertTrip(Trip trip) returns error? {
    mongodb:Collection collection = check getTripsCollection();
    check collection->insertOne(trip);
    log:printInfo("Trip inserted: " + trip.tripId);
}

// Find trip by ID
public function findTripById(string tripId) returns Trip|error? {
    mongodb:Collection collection = check getTripsCollection();
    map<json>? result = check collection->findOne({tripId: tripId});
    
    if result is () {
        return ();
    }
    
    return mapToTrip(result);
}

// Find all trips
public function findAllTrips(string? routeId = (), TripStatus? status = ()) returns Trip[]|error {
    mongodb:Collection collection = check getTripsCollection();
    
    map<json> filter = {};
    
    if routeId is string {
        filter["routeId"] = routeId;
    }
    
    if status is TripStatus {
        filter["status"] = status;
    }
    
    stream<map<json>, error?> resultStream = check collection->find(filter);
    
    Trip[] trips = [];
    check from map<json> doc in resultStream
        do {
            Trip trip = check mapToTrip(doc);
            trips.push(trip);
        };
    
    return trips;
}

// Update trip
public function updateTrip(string tripId, map<json> updates) returns error? {
    mongodb:Collection collection = check getTripsCollection();
    
    // Add updatedAt timestamp
    map<json> mutableUpdates = updates.clone();
    mutableUpdates["updatedAt"] = getCurrentTimestamp();
    
    map<json> filter = {tripId: tripId};
    
    // Create proper update document for MongoDB 5.2.2
    mongodb:Update updateDoc = {
        set: mutableUpdates
    };
    
    mongodb:UpdateResult result = check collection->updateOne(filter, updateDoc);
    
    if result.modifiedCount == 0 {
        return error("Trip not found or no changes made");
    }
    
    log:printInfo("Trip updated: " + tripId);
}

// Update trip status
public function updateTripStatus(string tripId, TripStatus status, string? delayReason = (), int delayMinutes = 0) returns error? {
    map<json> updates = {
        "status": status,
        "delayMinutes": delayMinutes
    };
    
    if delayReason is string {
        updates["delayReason"] = delayReason;
    }
    
    check updateTrip(tripId, updates);
}

// Delete trip
public function deleteTrip(string tripId) returns error? {
    mongodb:Collection collection = check getTripsCollection();
    map<json> filter = {tripId: tripId};
    mongodb:DeleteResult result = check collection->deleteOne(filter);
    
    if result.deletedCount == 0 {
        return error("Trip not found");
    }
    
    log:printInfo("Trip deleted: " + tripId);
}

// Find trips by route
public function findTripsByRoute(string routeId) returns Trip[]|error {
    return findAllTrips(routeId);
}

// Count available seats for a trip
public function getAvailableSeats(string tripId) returns int|error {
    Trip? trip = check findTripById(tripId);
    
    if trip is () {
        return error("Trip not found");
    }
    
    return trip.availableSeats;
}

// Helper function to convert map to Route
function mapToRoute(map<json> data) returns Route|error {
    // Extract intermediate stops
    json intermediateStopsJson = check data.intermediateStops;
    string[] intermediateStops = check intermediateStopsJson.cloneWithType();
    
    // Extract status
    string statusStr = (check data.status).toString();
    RouteStatus status = check statusStr.ensureType();
    
    // Convert distance from float/int to decimal
    json distanceJson = check data.distance;
    decimal distance;
    if distanceJson is int {
        distance = <decimal>distanceJson;
    } else if distanceJson is float {
        distance = <decimal>distanceJson;
    } else {
        distance = check decimal:fromString(distanceJson.toString());
    }
    
    // Convert fare from float/int to decimal
    json fareJson = check data.fare;
    decimal fare;
    if fareJson is int {
        fare = <decimal>fareJson;
    } else if fareJson is float {
        fare = <decimal>fareJson;
    } else {
        fare = check decimal:fromString(fareJson.toString());
    }
    
    Route route = {
        routeId: (check data.routeId).toString(),
        routeNumber: (check data.routeNumber).toString(),
        routeName: (check data.routeName).toString(),
        startLocation: (check data.startLocation).toString(),
        endLocation: (check data.endLocation).toString(),
        intermediateStops: intermediateStops,
        distance: distance,
        estimatedDuration: check int:fromString((check data.estimatedDuration).toString()),
        fare: fare,
        status: status,
        createdAt: (check data.createdAt).toString(),
        updatedAt: (check data.updatedAt).toString()
    };
    
    return route;
}

// Helper function to convert map to Trip
function mapToTrip(map<json> data) returns Trip|error {
    // Extract status
    string statusStr = (check data.status).toString();
    TripStatus status = check statusStr.ensureType();
    
    // Extract optional delayReason
    string? delayReason = data.delayReason is () ? () : (check data.delayReason).toString();
    
    Trip trip = {
        tripId: (check data.tripId).toString(),
        routeId: (check data.routeId).toString(),
        routeNumber: (check data.routeNumber).toString(),
        departureTime: (check data.departureTime).toString(),
        arrivalTime: (check data.arrivalTime).toString(),
        vehicleId: (check data.vehicleId).toString(),
        driverName: (check data.driverName).toString(),
        availableSeats: check int:fromString((check data.availableSeats).toString()),
        totalSeats: check int:fromString((check data.totalSeats).toString()),
        status: status,
        delayReason: delayReason,
        delayMinutes: check int:fromString((check data.delayMinutes).toString()),
        createdAt: (check data.createdAt).toString(),
        updatedAt: (check data.updatedAt).toString()
    };
    
    return trip;
}