// File: utils.bal
// Utility functions for password hashing, validation, and JWT handling

import ballerina/crypto;
import ballerina/random;
import ballerina/regex;
import ballerina/uuid;
import ballerina/time;
import ballerina/jwt;
import ballerina/log;

// JWT configuration
configurable string jwtSecret = ?;
configurable int jwtExpiryMinutes = 60;
configurable string jwtIssuer = "passenger-service";
configurable string jwtAudience = "transport-system";

// Generate unique passenger ID
public function generatePassengerId() returns string {
    string uid = uuid:createType1AsString();
    string shortId = regex:replaceAll(uid, "-", "").substring(0, 10).toUpperAscii();
    return "P" + shortId;
}

// Hash password using SHA256 with salt
public function hashPassword(string password) returns string|error {
    byte[] salt = check generateSalt();
    byte[] passwordBytes = password.toBytes();
    byte[] saltedPassword = [...passwordBytes, ...salt];
    byte[] hashedBytes = check crypto:hashSha256(saltedPassword);
    string saltHex = salt.toBase16();
    string hashHex = hashedBytes.toBase16();
    return saltHex + ":" + hashHex;
}

// Verify password
public function verifyPassword(string password, string hashedPassword) returns boolean|error {
    string[] parts = regex:split(hashedPassword, ":");
    
    if parts.length() != 2 {
        return false;
    }
    
    string saltHex = parts[0];
    string storedHashHex = parts[1];
    byte[] salt = check hexStringToBytes(saltHex);
    byte[] passwordBytes = password.toBytes();
    byte[] saltedPassword = [...passwordBytes, ...salt];
    byte[] hashedBytes = check crypto:hashSha256(saltedPassword);
    string inputHashHex = hashedBytes.toBase16();
    
    return inputHashHex == storedHashHex;
}

// Helper function to convert hex string to byte array
function hexStringToBytes(string hexString) returns byte[]|error {
    if hexString.length() % 2 != 0 {
        return error("Invalid hex string length");
    }
    
    byte[] bytes = [];
    int i = 0;
    while i < hexString.length() {
        string byteStr = hexString.substring(i, i + 2);
        int byteValue = check int:fromHexString(byteStr);
        bytes.push(<byte>byteValue);
        i += 2;
    }
    return bytes;
}

// Generate random salt
function generateSalt() returns byte[]|error {
    byte[] salt = [];
    int i = 0;
    while i < 16 {
        int randomByte = check random:createIntInRange(0, 256);
        salt.push(<byte>randomByte);
        i += 1;
    }
    return salt;
}

// Validate email format
public function isValidEmail(string email) returns boolean {
    string emailRegex = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$";
    return regex:matches(email, emailRegex);
}

// Validate password strength
public function isValidPassword(string password) returns boolean {
    if password.length() < 8 {
        return false;
    }
    boolean hasLetter = regex:matches(password, ".*[a-zA-Z].*");
    boolean hasNumber = regex:matches(password, ".*[0-9].*");
    return hasLetter && hasNumber;
}

// Validate phone number (Namibian format)
public function isValidPhoneNumber(string phoneNumber) returns boolean {
    string phoneRegex = "^(\\+264|264|0)[0-9]{9}$";
    return regex:matches(phoneNumber, phoneRegex);
}

// Generate proper JWT token with expiry
public function generateToken(string passengerId, string username) returns string|error {
    time:Utc currentTime = time:utcNow();
    decimal currentSeconds = <decimal>currentTime[0];
    
    // Convert expiry minutes to decimal and calculate expiry time
    decimal expiryMinutesDecimal = <decimal>jwtExpiryMinutes;
    decimal expirySeconds = currentSeconds + (expiryMinutesDecimal * 60.0d);
    
    jwt:IssuerConfig issuerConfig = {
        username: username,
        issuer: jwtIssuer,
        audience: [jwtAudience],
        expTime: expirySeconds,
        customClaims: {
            "passengerId": passengerId,
            "username": username,
            "role": "passenger"
        },
        // ✅ CORRECTED: Pass secret directly as string (HMAC symmetric key)
        signatureConfig: {
            algorithm: jwt:HS256,
            config: jwtSecret
        }
    };
    
    string jwtToken = check jwt:issue(issuerConfig);
    log:printInfo(string `Generated JWT token for passenger ${passengerId}, expires in ${jwtExpiryMinutes} minutes`);
    
    return jwtToken;
}

// Verify and validate JWT token
public function verifyToken(string token) returns jwt:Payload|error {
    jwt:ValidatorConfig validatorConfig = {
        issuer: jwtIssuer,
        audience: jwtAudience,
        signatureConfig: {
            secret: jwtSecret
        },
        clockSkew: 60
    };
    
    jwt:Payload payload = check jwt:validate(token, validatorConfig);
    log:printInfo("JWT token validated successfully");
    
    return payload;
}

// Extract passenger ID from JWT token
public function extractPassengerId(string token) returns string|error {
    jwt:Payload payload = check verifyToken(token);
    
    // Access customClaims safely
    anydata customClaimsData = payload["customClaims"];
    
    if customClaimsData is () {
        return error("Custom claims not found in token");
    }
    
    map<json> customClaims = <map<json>>customClaimsData;
    json passengerIdJson = customClaims["passengerId"];
    
    if passengerIdJson is () {
        return error("Passenger ID not found in token");
    }
    
    return passengerIdJson.toString();
}

// Extract username from JWT token
public function extractUsername(string token) returns string|error {
    jwt:Payload payload = check verifyToken(token);
    
    // Access customClaims safely
    anydata customClaimsData = payload["customClaims"];
    
    if customClaimsData is () {
        return error("Custom claims not found in token");
    }
    
    map<json> customClaims = <map<json>>customClaimsData;
    json usernameJson = customClaims["username"];
    
    if usernameJson is () {
        return error("Username not found in token");
    }
    
    return usernameJson.toString();
}

// Check if token is expired
public function isTokenExpired(string token) returns boolean {
    jwt:Payload|error payload = verifyToken(token);
    
    if payload is error {
        log:printWarn("Token validation failed: " + payload.message());
        return true;
    }
    
    return false;
}

// Convert UTC time to ISO string
public function utcToIsoString(time:Utc utcTime) returns string {
    return time:utcToString(utcTime);
}

// Generate a random session ID
public function generateSessionId() returns string {
    string uid = uuid:createType4AsString();
    return regex:replaceAll(uid, "-", "");
}