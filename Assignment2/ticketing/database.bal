// File: database.bal
// MongoDB database configuration and operations

import ballerinax/mongodb;
import ballerina/log;

// MongoDB configuration
configurable string mongoHost = ?;
configurable int mongoPort = ?;
configurable string mongoDatabase = ?;

// Collection names
const string TICKETS_COLLECTION = "tickets";
const string TRIPS_COLLECTION = "trips";

// MongoDB client instance
mongodb:Client mongoClient = check new ({
    connection: string `mongodb://${mongoHost}:${mongoPort}`
});

// Get database
function getDatabase() returns mongodb:Database|error {
    return mongoClient->getDatabase(mongoDatabase);
}

// Get tickets collection
public function getTicketsCollection() returns mongodb:Collection|error {
    mongodb:Database db = check getDatabase();
    return db->getCollection(TICKETS_COLLECTION);
}

// Get trips collection
public function getTripsCollection() returns mongodb:Collection|error {
    mongodb:Database db = check getDatabase();
    return db->getCollection(TRIPS_COLLECTION);
}

// ============================================
// TICKET OPERATIONS
// ============================================

// Insert ticket
public function insertTicket(Ticket ticket) returns error? {
    mongodb:Collection collection = check getTicketsCollection();
    check collection->insertOne(ticket);
    log:printInfo("Ticket inserted: " + ticket.ticketId);
}

// Find ticket by ID
public function findTicketById(string ticketId) returns Ticket|error? {
    mongodb:Collection collection = check getTicketsCollection();
    map<json>? result = check collection->findOne({ticketId: ticketId});
    
    if result is () {
        return ();
    }
    
    return mapToTicket(result);
}

// Find tickets by passenger ID
public function findTicketsByPassengerId(string passengerId, TicketStatus? status = ()) returns Ticket[]|error {
    mongodb:Collection collection = check getTicketsCollection();
    
    map<json> filter = {passengerId: passengerId};
    if status is TicketStatus {
        filter["status"] = status;
    }
    
    // ✅ Remove sort parameter and handle in-memory sorting
    stream<map<json>, error?> resultStream = check collection->find(filter);
    
    Ticket[] tickets = [];
    check from map<json> doc in resultStream
        do {
            Ticket ticket = check mapToTicket(doc);
            tickets.push(ticket);
        };
    
    // Sort by createdAt in descending order (newest first)
    tickets = from var ticket in tickets
             order by ticket.createdAt descending
             select ticket;
    
    return tickets;
}

// Find all tickets
public function findAllTickets(TicketStatus? status = ()) returns Ticket[]|error {
    mongodb:Collection collection = check getTicketsCollection();
    
    map<json> filter = {};
    if status is TicketStatus {
        filter = {status: status};
    }
    
    // ✅ Remove sort parameter and handle in-memory sorting
    stream<map<json>, error?> resultStream = check collection->find(filter);
    
    Ticket[] tickets = [];
    check from map<json> doc in resultStream
        do {
            Ticket ticket = check mapToTicket(doc);
            tickets.push(ticket);
        };
    
    // Sort by createdAt in descending order (newest first)
    tickets = from var ticket in tickets
             order by ticket.createdAt descending
             select ticket;
    
    return tickets;
}

// Update ticket status
public function updateTicketStatus(string ticketId, TicketStatus status, string? paymentId = (), string? validatedAt = ()) returns error? {
    mongodb:Collection collection = check getTicketsCollection();
    
    map<json> update = {
        status: status,
        updatedAt: getCurrentTimestamp()
    };
    
    if paymentId is string {
        update["paymentId"] = paymentId;
    }
    
    if validatedAt is string {
        update["validatedAt"] = validatedAt;
    }
    
    mongodb:UpdateResult result = check collection->updateOne(
        {ticketId: ticketId},
        {"$set": update}
    );
    
    if result.modifiedCount == 0 {
        return error("Ticket not found or not updated");
    }
    
    log:printInfo("Ticket status updated: " + ticketId + " -> " + status.toString());
}

// Delete ticket
public function deleteTicket(string ticketId) returns error? {
    mongodb:Collection collection = check getTicketsCollection();
    
    mongodb:DeleteResult result = check collection->deleteOne({ticketId: ticketId});
    
    if result.deletedCount == 0 {
        return error("Ticket not found");
    }
    
    log:printInfo("Ticket deleted: " + ticketId);
}

// Check for expired tickets and update their status
public function updateExpiredTickets() returns int|error {
    mongodb:Collection collection = check getTicketsCollection();
    
    string currentTime = getCurrentTimestamp();
    
    // Find tickets that are CREATED or PAID but expired
    map<json> filter = {
        status: {"$in": [CREATED, PAID]},
        validUntil: {"$lt": currentTime}
    };
    
    mongodb:UpdateResult result = check collection->updateMany(
        filter,
        {"$set": {status: EXPIRED, updatedAt: currentTime}}
    );
    
    int expiredCount = result.modifiedCount;
    if expiredCount > 0 {
        log:printInfo(string `Updated ${expiredCount} expired tickets`);
    }
    
    return expiredCount;
}

// ============================================
// TRIP OPERATIONS (cached from Transport Service)
// ============================================

// Find trip by ID
public function findTripById(string tripId) returns TripInfo|error? {
    mongodb:Collection collection = check getTripsCollection();
    map<json>? result = check collection->findOne({tripId: tripId});
    
    if result is () {
        return ();
    }
    
    return mapToTripInfo(result);
}

// ============================================
// HELPER FUNCTIONS
// ============================================

// Convert MongoDB map to Ticket record
function mapToTicket(map<json> data) returns Ticket|error {
    return {
        ticketId: (check data.ticketId).toString(),
        passengerId: (check data.passengerId).toString(),
        tripId: (check data.tripId).toString(),
        routeId: (check data.routeId).toString(),
        routeNumber: (check data.routeNumber).toString(),
        fare: check convertToDecimal(check data.fare),
        status: check (check data.status).ensureType(),
        qrCode: (check data.qrCode).toString(),
        purchasedAt: (check data.purchasedAt).toString(),
        validatedAt: data.validatedAt is () ? () : (check data.validatedAt).toString(),
        validUntil: (check data.validUntil).toString(),
        paymentId: data.paymentId is () ? () : (check data.paymentId).toString(),
        createdAt: (check data.createdAt).toString(),
        updatedAt: (check data.updatedAt).toString()
    };
}

// Convert MongoDB map to TripInfo record
function mapToTripInfo(map<json> data) returns TripInfo|error {
    return {
        tripId: (check data.tripId).toString(),
        routeId: (check data.routeId).toString(),
        routeNumber: (check data.routeNumber).toString(),
        fare: check convertToDecimal(check data.fare),
        departureTime: (check data.departureTime).toString(),
        arrivalTime: (check data.arrivalTime).toString(),
        availableSeats: check int:fromString((check data.availableSeats).toString()),
        status: (check data.status).toString()
    };
}

// Convert various numeric types to decimal
function convertToDecimal(json value) returns decimal|error {
    if value is decimal {
        return value;
    } else if value is float {
        return <decimal>value;
    } else if value is int {
        return <decimal>value;
    } else if value is string {
        return decimal:fromString(value);
    }
    return error("Cannot convert to decimal");
}