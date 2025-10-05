// File: main.bal
// Main entry point

import ballerina/log;

public function main() returns error? {
    log:printInfo("Starting Ticketing Service...");
    log:printInfo("Service running on port: " + servicePort.toString());
    log:printInfo("MongoDB: " + mongoHost + ":" + mongoPort.toString());
    
    // TODO: Start Kafka listener when implemented
    // startPaymentListener();
}