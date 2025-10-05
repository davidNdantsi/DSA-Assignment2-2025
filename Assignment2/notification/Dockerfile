# File: notification-service/Dockerfile

FROM ballerina/ballerina:2201.12.9 AS builder
WORKDIR /home/ballerina

# Copy project files
COPY Ballerina.toml Config.toml ./
COPY *.bal ./

# Build WITHOUT --offline to fetch dependencies
RUN bal build

FROM ballerina/ballerina:2201.12.9
USER root
RUN apk add --no-cache bash procps
USER ballerina
WORKDIR /home/ballerina

# Copy the built jar
COPY --from=builder /home/ballerina/target/bin/notification.jar ./
COPY Config.toml ./

ENV serviceName="Notification Service" \
    mongoHost="mongodb" \
    mongoPort="27017" \
    mongoDatabase="transport_ticketing_system" \
    kafkaBootstrapServers="kafka:9092" \
    kafkaGroupId="notification-service-group" \
    scheduleUpdatesTopic="schedule.updates" \
    ticketValidatedTopic="ticket.validated" \
    ticketCreatedTopic="ticket.created" \
    enableConsoleLogging="true" \
    enableDatabaseStorage="true"

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f "java" || exit 1

CMD ["bal", "run", "notification.jar"]