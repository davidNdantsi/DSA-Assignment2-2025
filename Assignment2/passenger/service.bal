// File: service.bal
// HTTP service endpoints for Passenger Service

import ballerina/http;
import ballerina/log;
import ballerina/time;

configurable string serviceHost = ?;
configurable int servicePort = ?;

// Request/Response types
type RegisterRequest record {|
    string username;
    string email;
    string password;
    string firstName;
    string lastName;
    string phoneNumber;
|};

type LoginRequest record {|
    string username;
    string password;
|};

type LoginResponse record {|
    string passengerId;
    string username;
    string email;
    string firstName;
    string lastName;
    string token;
    string message;
|};

type PassengerResponse record {|
    string passengerId;
    string username;
    string email;
    string firstName;
    string lastName;
    string phoneNumber;
    string status;
    string createdAt;
|};

// Passenger status constants
const string ACTIVE = "ACTIVE";
const string INACTIVE = "INACTIVE";
const string SUSPENDED = "SUSPENDED";

// Passenger record type
type Passenger record {|
    string passengerId;
    string username;
    string email;
    string password;
    string firstName;
    string lastName;
    string phoneNumber;
    time:Utc createdAt;
    time:Utc updatedAt;
    string status;
|};

// Ticket record type
type Ticket record {|
    string ticketId;
    string passengerId;
    string ticketType;
    string? tripId;
    string? routeId;
    decimal price;
    string currency;
    int ridesTotal;
    int ridesUsed;
    string validFrom;
    string validUntil;
    string status;
    string qrCode;
    string purchasedAt;
|};

public type HealthResponse record {|
    string servic;
    string status;
    string timestamp;
|};

// HTTP service
service /passengers on new http:Listener(servicePort) {

    // Health check endpoint
    resource function get health() returns json {
        return {
            "service": "passenger-service",
            "status": "UP",
            "timestamp": time:utcToString(time:utcNow())
        };
    }

    // Register new passenger
    resource function post register(@http:Payload RegisterRequest request) returns http:Created|http:BadRequest|http:InternalServerError {
        log:printInfo("Registration request received for: " + request.username);
        
        // Validate input
        if request.username.trim().length() == 0 {
            return <http:BadRequest>{
                body: {message: "Username is required"}
            };
        }
        
        if !isValidEmail(request.email) {
            return <http:BadRequest>{
                body: {message: "Invalid email format"}
            };
        }
        
        if !isValidPassword(request.password) {
            return <http:BadRequest>{
                body: {message: "Password must be at least 8 characters and contain letters and numbers"}
            };
        }
        
        if !isValidPhoneNumber(request.phoneNumber) {
            return <http:BadRequest>{
                body: {message: "Invalid phone number format"}
            };
        }
        
        // Check if username already exists
        boolean|error usernameCheck = usernameExists(request.username);
        if usernameCheck is error {
            log:printError("Error checking username", usernameCheck);
            return <http:InternalServerError>{
                body: {message: "Internal server error"}
            };
        }
        
        if usernameCheck {
            return <http:BadRequest>{
                body: {message: "Username already exists"}
            };
        }
        
        // Check if email already exists
        boolean|error emailCheck = emailExists(request.email);
        if emailCheck is error {
            log:printError("Error checking email", emailCheck);
            return <http:InternalServerError>{
                body: {message: "Internal server error"}
            };
        }
        
        if emailCheck {
            return <http:BadRequest>{
                body: {message: "Email already exists"}
            };
        }
        
        // Hash password
        string|error hashedPassword = hashPassword(request.password);
        if hashedPassword is error {
            log:printError("Error hashing password", hashedPassword);
            return <http:InternalServerError>{
                body: {message: "Error processing password"}
            };
        }
        
        // Create passenger record
        time:Utc now = time:utcNow();
        Passenger passenger = {
            passengerId: generatePassengerId(),
            username: request.username,
            email: request.email,
            password: hashedPassword,
            firstName: request.firstName,
            lastName: request.lastName,
            phoneNumber: request.phoneNumber,
            createdAt: now,
            updatedAt: now,
            status: ACTIVE
        };
        
        // Insert into database
        error? insertResult = insertPassenger(passenger);
        if insertResult is error {
            log:printError("Error inserting passenger", insertResult);
            return <http:InternalServerError>{
                body: {message: "Error creating account"}
            };
        }
        
        // Return success response
        PassengerResponse response = {
            passengerId: passenger.passengerId,
            username: passenger.username,
            email: passenger.email,
            firstName: passenger.firstName,
            lastName: passenger.lastName,
            phoneNumber: passenger.phoneNumber,
            status: passenger.status,
            createdAt: utcToIsoString(passenger.createdAt)
        };
        
        log:printInfo("Passenger registered successfully: " + passenger.passengerId);
        
        return <http:Created>{
            body: response
        };
    }

    // Login passenger - WITH PROPER JWT TOKEN
    resource function post login(@http:Payload LoginRequest request) returns LoginResponse|http:Unauthorized|http:InternalServerError {
        log:printInfo("Login request received for: " + request.username);
        
        // Validate input
        if request.username.trim().length() == 0 || request.password.trim().length() == 0 {
            return <http:Unauthorized>{
                body: {message: "Invalid credentials"}
            };
        }
        
        // Find passenger by username
        Passenger|error? passenger = findPassengerByUsername(request.username);
        
        if passenger is error {
            log:printError("Error finding passenger", passenger);
            return <http:InternalServerError>{
                body: {message: "Internal server error"}
            };
        }
        
        if passenger is () {
            log:printWarn("Login failed: username not found - " + request.username);
            return <http:Unauthorized>{
                body: {message: "Invalid credentials"}
            };
        }
        
        // Verify password
        boolean|error passwordValid = verifyPassword(request.password, passenger.password);
        
        if passwordValid is error {
            log:printError("Error verifying password", passwordValid);
            return <http:InternalServerError>{
                body: {message: "Internal server error"}
            };
        }
        
        if !passwordValid {
            log:printWarn("Login failed: invalid password for user - " + request.username);
            return <http:Unauthorized>{
                body: {message: "Invalid credentials"}
            };
        }
        
        // Check if account is active
        if passenger.status != ACTIVE {
            log:printWarn("Login failed: account not active - " + request.username);
            return <http:Unauthorized>{
                body: {message: "Account is not active"}
            };
        }
        
        // Generate proper JWT token
        string|error token = generateToken(passenger.passengerId, passenger.username);
        
        if token is error {
            log:printError("Error generating token", token);
            return <http:InternalServerError>{
                body: {message: "Error generating authentication token"}
            };
        }
        
        log:printInfo("Login successful for: " + passenger.username);
        
        // Return login response with JWT token
        LoginResponse response = {
            passengerId: passenger.passengerId,
            username: passenger.username,
            email: passenger.email,
            firstName: passenger.firstName,
            lastName: passenger.lastName,
            token: token,
            message: "Login successful"
        };
        
        return response;
    }

    // Get passenger tickets
    resource function get [string passengerId]/tickets() returns Ticket[]|http:NotFound|http:InternalServerError {
        log:printInfo("Fetching tickets for passenger: " + passengerId);
        
        // Verify passenger exists
        Passenger|error? passenger = findPassengerById(passengerId);
        
        if passenger is error {
            log:printError("Error finding passenger", passenger);
            return <http:InternalServerError>{
                body: {message: "Internal server error"}
            };
        }
        
        if passenger is () {
            log:printWarn("Passenger not found: " + passengerId);
            return <http:NotFound>{
                body: {message: "Passenger not found"}
            };
        }
        
        // Get tickets
        Ticket[]|error tickets = getTicketsByPassengerId(passengerId);
        
        if tickets is error {
            log:printError("Error fetching tickets", tickets);
            return <http:InternalServerError>{
                body: {message: "Error fetching tickets"}
            };
        }
        
        log:printInfo(string `Found ${tickets.length()} tickets for passenger ${passengerId}`);
        
        return tickets;
    }

    // Get passenger profile
    resource function get [string passengerId]() returns PassengerResponse|http:NotFound|http:InternalServerError {
        log:printInfo("Fetching profile for passenger: " + passengerId);
        
        Passenger|error? passenger = findPassengerById(passengerId);
        
        if passenger is error {
            log:printError("Error finding passenger", passenger);
            return <http:InternalServerError>{
                body: {message: "Internal server error"}
            };
        }
        
        if passenger is () {
            log:printWarn("Passenger not found: " + passengerId);
            return <http:NotFound>{
                body: {message: "Passenger not found"}
            };
        }
        
        PassengerResponse response = {
            passengerId: passenger.passengerId,
            username: passenger.username,
            email: passenger.email,
            firstName: passenger.firstName,
            lastName: passenger.lastName,
            phoneNumber: passenger.phoneNumber,
            status: passenger.status,
            createdAt: utcToIsoString(passenger.createdAt)
        };
        
        return response;
    }
}