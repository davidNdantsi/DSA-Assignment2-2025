// File: kafka_consumer.bal
// Kafka Consumer Configuration and Listeners

import ballerinax/kafka;
import ballerina/log;

configurable string kafkaBootstrapServers = ?;
configurable string kafkaGroupId = ?;
configurable string scheduleUpdatesTopic = ?;
configurable string ticketValidatedTopic = ?;
configurable string ticketCreatedTopic = ?;

// ============================================
// KAFKA CONSUMER CONFIGURATION
// ============================================

kafka:ConsumerConfiguration consumerConfig = {
    groupId: kafkaGroupId,
    topics: [scheduleUpdatesTopic, ticketValidatedTopic, ticketCreatedTopic],
    offsetReset: kafka:OFFSET_RESET_EARLIEST,
    autoCommit: true
};

final kafka:Consumer kafkaConsumer = check new (kafkaBootstrapServers, consumerConfig);

// ============================================
// KAFKA MESSAGE LISTENER
// ============================================

public function startKafkaListener() returns error? {
    log:printInfo("Starting Kafka consumer...");
    log:printInfo(string `Subscribed to topics: ${scheduleUpdatesTopic}, ${ticketValidatedTopic}, ${ticketCreatedTopic}`);
    
    while true {
        kafka:BytesConsumerRecord[] records = check kafkaConsumer->poll(1);
        
        foreach kafka:BytesConsumerRecord rec in records {
            byte[] messageBytes = rec.value;
            string messageStr = check string:fromBytes(messageBytes);
            
            log:printInfo("Received Kafka message");
            
            // ✅ FIX: Try to process with intelligent detection
            error? result = processMessageByStructure(messageStr);
            if result is error {
                log:printError("Failed to process message", result);
            }
        }
    }
}

// ✅ IMPROVED: Better message detection logic
function processMessageByStructure(string message) returns error? {
    json jsonMsg = check message.fromJsonString();
    
    // ✅ Check for unique fields in priority order
    
    // 1. Check for ScheduleUpdateMessage (has disruptionId)
    if jsonMsg.disruptionId is json && jsonMsg.severity is json {
        log:printInfo("Detected: Schedule Update Message");
        ScheduleUpdateMessage msg = check jsonMsg.cloneWithType();
        check createScheduleUpdateNotification(msg);
        return;
    }
    
    // 2. Check for TicketValidatedMessage (has validationId)
    if jsonMsg.validationId is json && jsonMsg.validatedAt is json {
        log:printInfo("Detected: Ticket Validated Message");
        TicketValidatedMessage msg = check jsonMsg.cloneWithType();
        check createTicketValidationNotification(msg);
        return;
    }
    
    // 3. Check for TicketCreatedMessage (has qrCode and purchaseTime)
    if jsonMsg.qrCode is json && jsonMsg.purchaseTime is json {
        log:printInfo("Detected: Ticket Created Message");
        TicketCreatedMessage msg = check jsonMsg.cloneWithType();
        check createTicketPurchaseNotification(msg);
        return;
    }
    
    return error("Unknown message format - no matching handler found");
}