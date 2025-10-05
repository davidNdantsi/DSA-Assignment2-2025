import ballerina/log;

public function main() returns error? {
    log:printInfo("Starting Passenger Service...");
    log:printInfo("Service running on port: " + servicePort.toString());
}