// File: notification_handler.bal
// Notification Creation and Sending Logic

import ballerina/log;
import ballerina/uuid;

configurable boolean enableConsoleLogging = ?;
configurable boolean enableDatabaseStorage = ?;

// ============================================
// NOTIFICATION CREATION
// ============================================

public function createTicketPurchaseNotification(TicketCreatedMessage ticketMsg) returns error? {
    string subject = "Ticket Purchase Confirmation";
    string message = string `
╔════════════════════════════════════════╗
║     TICKET PURCHASE CONFIRMATION       ║
╔════════════════════════════════════════╗

Ticket ID: ${ticketMsg.ticketId}
Route: ${ticketMsg.routeName}
Departure: ${ticketMsg.scheduledDeparture}
Price: $${ticketMsg.price.toString()}

QR Code: ${ticketMsg.qrCode}

Thank you for your purchase!
Present this ticket at the departure gate.
    `;
    
    Notification notification = {
        notificationId: generateNotificationId(),
        passengerId: ticketMsg.passengerId,
        notificationType: TICKET_PURCHASED,
        channel: CONSOLE,
        subject: subject,
        message: message,
        status: PENDING,
        createdAt: getCurrentTimestamp(),
        metadata: {
            "ticketId": ticketMsg.ticketId,
            "tripId": ticketMsg.tripId,
            "routeId": ticketMsg.routeId
        }
    };
    
    check sendNotification(notification);
}

public function createTicketValidationNotification(TicketValidatedMessage validationMsg) returns error? {
    string subject = "Ticket Validated Successfully";
    string message = string `
╔════════════════════════════════════════╗
║      TICKET VALIDATION CONFIRMED       ║
╔════════════════════════════════════════╗

Validation ID: ${validationMsg.validationId}
Ticket ID: ${validationMsg.ticketId}
Trip ID: ${validationMsg.tripId}
Validated At: ${validationMsg.validatedAt}
Location: ${validationMsg.location}
Validated By: ${validationMsg.validatedBy}

Have a safe journey!
    `;
    
    Notification notification = {
        notificationId: generateNotificationId(),
        passengerId: validationMsg.passengerId,
        notificationType: TICKET_VALIDATED,
        channel: CONSOLE,
        subject: subject,
        message: message,
        status: PENDING,
        createdAt: getCurrentTimestamp(),
        metadata: {
            "validationId": validationMsg.validationId,
            "ticketId": validationMsg.ticketId,
            "tripId": validationMsg.tripId
        }
    };
    
    check sendNotification(notification);
}

public function createScheduleUpdateNotification(ScheduleUpdateMessage scheduleMsg) returns error? {
    string severityIcon = getSeverityIcon(scheduleMsg.severity);
    
    // ✅ FIX: Proper optional string handling
    string endTimeText = scheduleMsg.endTime is string ? 
        string `End Time: ${<string>scheduleMsg.endTime}` : 
        "End Time: Unknown";
    
    string subject = string `${severityIcon} Service Disruption: ${scheduleMsg.title}`;
    string message = string `
╔════════════════════════════════════════╗
║       SERVICE DISRUPTION ALERT         ║
╔════════════════════════════════════════╗

${severityIcon} Severity: ${scheduleMsg.severity.toString()}

Title: ${scheduleMsg.title}
Description: ${scheduleMsg.description}

Affected Routes: ${scheduleMsg.affectedRoutes.toString()}
Start Time: ${scheduleMsg.startTime}
${endTimeText}

Please plan your journey accordingly.
    `;
    
    Notification notification = {
        notificationId: generateNotificationId(),
        passengerId: "SYSTEM",
        notificationType: SCHEDULE_UPDATE,
        channel: CONSOLE,
        subject: subject,
        message: message,
        status: PENDING,
        createdAt: getCurrentTimestamp(),
        metadata: {
            "disruptionId": scheduleMsg.disruptionId,
            "severity": scheduleMsg.severity.toString(),
            "affectedRoutes": scheduleMsg.affectedRoutes
        }
    };
    
    check sendNotification(notification);
}

// ============================================
// NOTIFICATION SENDING
// ============================================

function sendNotification(Notification notification) returns error? {
    log:printInfo(string `Processing notification: ${notification.notificationId}`);
    
    // ✅ Send to console
    if enableConsoleLogging {
        sendToConsole(notification);
    }
    
    // ✅ Store in database
    if enableDatabaseStorage {
        error? insertResult = insertNotification(notification);
        if insertResult is error {
            log:printError("Failed to store notification in database", insertResult);
            notification.status = FAILED;
            notification.errorMessage = insertResult.message();
        } else {
            notification.status = DELIVERED;
            notification.sentAt = getCurrentTimestamp();
            
            // Update status in database
            error? updateResult = updateNotificationStatus(
                notification.notificationId, 
                DELIVERED
            );
            if updateResult is error {
                log:printError("Failed to update notification status", updateResult);
            }
        }
    } else {
        notification.status = SENT;
        notification.sentAt = getCurrentTimestamp();
    }
    
    log:printInfo(string `Notification processed: ${notification.notificationId} - Status: ${notification.status.toString()}`);
}

function sendToConsole(Notification notification) {
    string separator = repeatString("=", 60);
    
    log:printInfo("\n" + string `
${separator}
${notification.subject}
${separator}
${notification.message}
${separator}
Notification ID: ${notification.notificationId}
Passenger ID: ${notification.passengerId}
Type: ${notification.notificationType.toString()}
Sent At: ${getCurrentTimestamp()}
${separator}
    `);
}

// ============================================
// HELPER FUNCTIONS
// ============================================

function getSeverityIcon(DisruptionSeverity severity) returns string {
    match severity {
        LOW => {
            return "ℹ️";
        }
        MEDIUM => {
            return "⚠️";
        }
        HIGH => {
            return "🚨";
        }
        CRITICAL => {
            return "🔴";
        }
    }
    return "📢";
}

function generateNotificationId() returns string {
    return "NOTIF-" + uuid:createType1AsString().substring(0, 8).toUpperAscii();
}

function repeatString(string str, int count) returns string {
    string result = "";
    int i = 0;
    while i < count {
        result = result + str;
        i = i + 1;
    }
    return result;
}