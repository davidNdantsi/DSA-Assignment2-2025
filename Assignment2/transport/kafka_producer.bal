// File: kafka_producer.bal
// Kafka producer for publishing schedule updates

import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerinax/kafka;

// ============================================
// Kafka Configuration
// ============================================

configurable string kafkaBootstrapServers = ?;
configurable string kafkaScheduleUpdatesTopic = ?;
configurable string kafkaProducerClientId = ?;
configurable string kafkaAcks = "all";
configurable int kafkaRetries = 3;
configurable int kafkaMaxInFlightRequestsPerConnection = 5;
configurable boolean kafkaEnableIdempotence = true;

// ============================================
// Initialize Kafka Producer
// ============================================

// Convert string acks to ProducerAcks enum
kafka:ProducerAcks producerAcks = kafkaAcks == "all" ? kafka:ACKS_ALL : 
                                   kafkaAcks == "1" ? kafka:ACKS_SINGLE :
                                   kafka:ACKS_NONE;

kafka:Producer scheduleUpdatesProducer = check new (
    kafkaBootstrapServers,  // ✅ FIX: Pass directly, not in config
    {
        clientId: kafkaProducerClientId,
        acks: producerAcks,  // ✅ FIX: Use enum type, not string
        retryCount: kafkaRetries,
        maxInFlightRequestsPerConnection: kafkaMaxInFlightRequestsPerConnection,
        enableIdempotence: kafkaEnableIdempotence
    }
);

// ============================================
// Kafka Publishing Functions
// ============================================

# Publishes a schedule update event to Kafka
#
# + trip - The trip object
# + previousStatus - Previous status of the trip
# + eventType - Type of schedule event
# + return - Result of the publish operation
public function publishScheduleUpdate(
    Trip trip,
    TripStatus previousStatus,
    ScheduleEventType eventType
) returns KafkaPublishResult {
    
    // Create event
    ScheduleUpdateEvent event = {
        eventId: uuid:createType1AsString(),
        eventType: eventType,
        tripId: trip.tripId,
        routeId: trip.routeId,
        routeNumber: trip.routeNumber,
        previousStatus: previousStatus,
        newStatus: trip.status,
        delayMinutes: trip.delayMinutes,
        reason: trip.delayReason,
        timestamp: time:utcToString(time:utcNow())
    };

    // Convert to JSON
    json|error eventJson = event.toJson();
    if eventJson is error {
        log:printError("Failed to convert event to JSON", 'error = eventJson);
        return {
            success: false,
            errorMessage: "Failed to serialize event: " + eventJson.message()
        };
    }

    // Publish to Kafka
    kafka:Error? result = scheduleUpdatesProducer->send({
        topic: kafkaScheduleUpdatesTopic,
        value: eventJson.toJsonString().toBytes()
    });

    if result is kafka:Error {
        log:printError("Failed to publish schedule update to Kafka", 'error = result);
        return {
            success: false,
            errorMessage: "Kafka publish failed: " + result.message()
        };
    }

    log:printInfo(string `Published ${eventType} event for trip ${trip.tripId} (Route: ${trip.routeNumber})`);
    return {
        success: true,
        errorMessage: ()
    };
}

# Publishes a delay event
#
# + trip - The delayed trip
# + previousStatus - Previous status before delay
# + return - Result of the publish operation
public function publishDelayEvent(
    Trip trip,
    TripStatus previousStatus
) returns KafkaPublishResult {
    return publishScheduleUpdate(trip, previousStatus, DELAY);
}

# Publishes a cancellation event
#
# + trip - The cancelled trip
# + previousStatus - Previous status before cancellation
# + return - Result of the publish operation
public function publishCancellationEvent(
    Trip trip,
    TripStatus previousStatus
) returns KafkaPublishResult {
    return publishScheduleUpdate(trip, previousStatus, CANCELLATION);
}

# Publishes a general schedule change event
#
# + trip - The trip with schedule changes
# + previousStatus - Previous status
# + return - Result of the publish operation
public function publishScheduleChangeEvent(
    Trip trip,
    TripStatus previousStatus
) returns KafkaPublishResult {
    return publishScheduleUpdate(trip, previousStatus, SCHEDULE_CHANGE);
}

# Gracefully closes the Kafka producer
#
# + return - Error if closing fails
public function closeKafkaProducer() returns error? {
    check scheduleUpdatesProducer->close();
    log:printInfo("Kafka producer closed successfully");
}