// File: main.bal
// Notification Service Entry Point

import ballerina/log;

configurable string serviceName = ?;

public function main() returns error? {
    log:printInfo(string `Starting ${serviceName}...`);
    log:printInfo("Initializing Kafka consumer...");
    
    // Start Kafka listener (this will run indefinitely)
    check startKafkaListener();
}