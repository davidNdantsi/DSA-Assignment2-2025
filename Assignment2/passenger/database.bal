// File: database.bal
// Database operations for Passenger Service

import ballerina/log;
import ballerinax/mongodb;
import ballerina/time;

// MongoDB configuration
configurable string mongoHost = ?;
configurable int mongoPort = ?;
configurable string mongoDatabase = ?;

// MongoDB client instance
mongodb:Client mongoClient = check new ({
    connection: string `mongodb://${mongoHost}:${mongoPort}`
});

// Get database
function getDatabase() returns mongodb:Database|error {
    return mongoClient->getDatabase(mongoDatabase);
}

// Get passengers collection
function getPassengersCollection() returns mongodb:Collection|error {
    mongodb:Database db = check getDatabase();
    return db->getCollection("passengers");
}

// Get tickets collection
function getTicketsCollection() returns mongodb:Collection|error {
    mongodb:Database db = check getDatabase();
    return db->getCollection("tickets");
}

// Check if username exists
function usernameExists(string username) returns boolean|error {
    mongodb:Collection passengers = check getPassengersCollection();
    int count = check passengers->countDocuments({username: username});
    return count > 0;
}

// Check if email exists
function emailExists(string email) returns boolean|error {
    mongodb:Collection passengers = check getPassengersCollection();
    int count = check passengers->countDocuments({email: email});
    return count > 0;
}

// Insert new passenger
function insertPassenger(Passenger passenger) returns error? {
    mongodb:Collection passengers = check getPassengersCollection();
    check passengers->insertOne(passenger);
    log:printInfo("Passenger registered: " + passenger.username);
}

// Find passenger by username
function findPassengerByUsername(string username) returns Passenger|error? {
    mongodb:Collection passengers = check getPassengersCollection();
    map<json>? result = check passengers->findOne({username: username});
    
    if result is () {
        return ();
    }
    
    return mapToPassenger(result);
}

// Find passenger by ID
function findPassengerById(string passengerId) returns Passenger|error? {
    mongodb:Collection passengers = check getPassengersCollection();
    map<json>? result = check passengers->findOne({passengerId: passengerId});
    
    if result is () {
        return ();
    }
    
    return mapToPassenger(result);
}

// Get tickets by passenger ID
function getTicketsByPassengerId(string passengerId) returns Ticket[]|error {
    mongodb:Collection tickets = check getTicketsCollection();
    
    stream<map<json>, error?> resultStream = check tickets->find({passengerId: passengerId});
    
    Ticket[] ticketList = [];
    check from map<json> doc in resultStream
        do {
            Ticket ticket = check mapToTicket(doc);
            ticketList.push(ticket);
        };
    
    return ticketList;
}

// Helper function to convert map to Passenger
function mapToPassenger(map<json> data) returns Passenger|error {
    return {
        passengerId: (check data.passengerId).toString(),
        username: (check data.username).toString(),
        email: (check data.email).toString(),
        password: (check data.password).toString(),
        firstName: (check data.firstName).toString(),
        lastName: (check data.lastName).toString(),
        phoneNumber: (check data.phoneNumber).toString(),
        createdAt: check time:utcFromString((check data.createdAt).toString()),
        updatedAt: check time:utcFromString((check data.updatedAt).toString()),
        status: check data.status.ensureType()
    };
}

// Helper function to convert map to Ticket
function mapToTicket(map<json> data) returns Ticket|error {
    return {
        ticketId: (check data.ticketId).toString(),
        passengerId: (check data.passengerId).toString(),
        ticketType: (check data.ticketType).toString(),
        tripId: data.tripId is () ? () : (check data.tripId).toString(),
        routeId: data.routeId is () ? () : (check data.routeId).toString(),
        price: check decimal:fromString((check data.price).toString()),
        currency: (check data.currency).toString(),
        ridesTotal: check int:fromString((check data.ridesTotal).toString()),
        ridesUsed: check int:fromString((check data.ridesUsed).toString()),
        validFrom: (check data.validFrom).toString(),
        validUntil: (check data.validUntil).toString(),
        status: (check data.status).toString(),
        qrCode: (check data.qrCode).toString(),
        purchasedAt: (check data.purchasedAt).toString()
    };
}