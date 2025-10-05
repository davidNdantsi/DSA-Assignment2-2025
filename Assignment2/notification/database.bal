// File: database.bal
// MongoDB Database Operations for Notification Service

import ballerinax/mongodb;
import ballerina/log;


configurable string mongoHost = ?;
configurable int mongoPort = ?;
configurable string mongoDatabase = ?;

// MongoDB client
final mongodb:Client mongoClient = check new ({
    connection: string `mongodb://${mongoHost}:${mongoPort}`
});

// ============================================
// COLLECTION HELPERS
// ============================================

function getNotificationsCollection() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase(mongoDatabase);
    return db->getCollection("notifications");
}

function getPassengersCollection() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase(mongoDatabase);
    return db->getCollection("passengers");
}

// ============================================
// NOTIFICATION OPERATIONS
// ============================================

public function insertNotification(Notification notification) returns error? {
    mongodb:Collection notificationsCollection = check getNotificationsCollection();
    
    // Convert enum types to strings for MongoDB storage
    NotificationRecord notificationRecord = {
        notificationId: notification.notificationId,
        passengerId: notification.passengerId,
        'type: notification.notificationType.toString(),
        channel: notification.channel.toString(),
        subject: notification.subject,
        message: notification.message,
        status: notification.status.toString(),
        errorMessage: notification.errorMessage,
        createdAt: notification.createdAt,
        sentAt: notification.sentAt,
        metadata: notification.metadata
    };
    
    check notificationsCollection->insertOne(notificationRecord);
    log:printInfo(string `Notification stored in database: ${notification.notificationId}`);
}

public function updateNotificationStatus(
    string notificationId, 
    NotificationStatus status, 
    string? errorMessage = ()
) returns error? {
    mongodb:Collection notificationsCollection = check getNotificationsCollection();
    
    map<json> filter = {"notificationId": notificationId};
    
    map<json> setFields = {
        "status": status.toString(),
        "sentAt": getCurrentTimestamp()
    };
    
    if errorMessage is string {
        setFields["errorMessage"] = errorMessage;
    }
    
    mongodb:Update update = {
        set: setFields
    };
    
    mongodb:UpdateResult result = check notificationsCollection->updateOne(filter, update);
    
    if result.modifiedCount == 0 {
        return error(string `Notification not found: ${notificationId}`);
    }
    
    log:printInfo(string `Notification status updated: ${notificationId} -> ${status.toString()}`);
}

public function findNotificationsByPassenger(string passengerId) returns Notification[]|error {
    mongodb:Collection notificationsCollection = check getNotificationsCollection();
    
    map<json> filter = {"passengerId": passengerId};
    
    // Create FindOptions with sort and limit
    mongodb:FindOptions findOptions = {
        sort: {"createdAt": -1},
        'limit: 50
    };
    
    // Use find() with filter and options
    stream<NotificationRecord, error?> result = check notificationsCollection->find(filter, findOptions);
    
    NotificationRecord[] records = check from NotificationRecord r in result select r;
    
    // Convert back to Notification type with safe enum conversion
    Notification[] notifications = [];
    foreach NotificationRecord rec in records {
        // Safe enum conversions
        NotificationType notifType = check parseNotificationType(rec.'type);
        NotificationChannel notifChannel = check parseNotificationChannel(rec.channel);
        NotificationStatus notifStatus = check parseNotificationStatus(rec.status);
        
        notifications.push({
            notificationId: rec.notificationId,
            passengerId: rec.passengerId,
            notificationType: notifType,
            channel: notifChannel,
            subject: rec.subject,
            message: rec.message,
            status: notifStatus,
            errorMessage: rec.errorMessage,
            createdAt: rec.createdAt,
            sentAt: rec.sentAt,
            metadata: rec.metadata
        });
    }
    
    return notifications;
}

public function getPassengerEmail(string passengerId) returns string|error {
    mongodb:Collection passengersCollection = check getPassengersCollection();
    
    map<json> filter = {"passengerId": passengerId};
    stream<map<json>, error?> result = check passengersCollection->find(filter);
    
    map<json>[] passengers = check from map<json> p in result select p;
    
    if passengers.length() == 0 {
        return error(string `Passenger not found: ${passengerId}`);
    }
    
    json emailJson = passengers[0]["email"];
    if emailJson is string {
        return emailJson;
    }
    
    return error("Email not found for passenger");
}

// ============================================
// UTILITY FUNCTIONS - ENUM PARSING
// ============================================

function parseNotificationType(string typeStr) returns NotificationType|error {
    match typeStr {
        "TICKET_PURCHASED" => {
            return TICKET_PURCHASED;
        }
        "TICKET_VALIDATED" => {
            return TICKET_VALIDATED;
        }
        "SCHEDULE_UPDATE" => {
            return SCHEDULE_UPDATE;
        }
        "TRIP_DELAYED" => {
            return TRIP_DELAYED;
        }
        "TRIP_CANCELLED" => {
            return TRIP_CANCELLED;
        }
        "PAYMENT_SUCCESS" => {
            return PAYMENT_SUCCESS;
        }
        "PAYMENT_FAILED" => {
            return PAYMENT_FAILED;
        }
        _ => {
            return error(string `Invalid notification type: ${typeStr}`);
        }
    }
}

function parseNotificationChannel(string channelStr) returns NotificationChannel|error {
    match channelStr {
        "EMAIL" => {
            return EMAIL;
        }
        "SMS" => {
            return SMS;
        }
        "PUSH" => {
            return PUSH;
        }
        "CONSOLE" => {
            return CONSOLE;
        }
        _ => {
            return error(string `Invalid notification channel: ${channelStr}`);
        }
    }
}

function parseNotificationStatus(string statusStr) returns NotificationStatus|error {
    match statusStr {
        "PENDING" => {
            return PENDING;
        }
        "SENT" => {
            return SENT;
        }
        "DELIVERED" => {
            return DELIVERED;
        }
        "FAILED" => {
            return FAILED;
        }
        _ => {
            return error(string `Invalid notification status: ${statusStr}`);
        }
    }
}