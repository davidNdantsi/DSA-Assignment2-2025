# ============================================
# Stage 1: Build Stage
# ============================================
FROM ballerina/ballerina:2201.12.9 AS builder

WORKDIR /home/ballerina

# Copy project files
COPY Ballerina.toml config.toml ./
COPY *.bal ./

# Build the Ballerina project (downloads dependencies from Ballerina Central)
RUN bal build

# ============================================
# Stage 2: Runtime Stage
# ============================================
FROM ballerina/ballerina:2201.12.9

# Install health check utilities (Alpine uses apk, not apt-get)
USER root
RUN apk add --no-cache curl bash

USER ballerina
WORKDIR /home/ballerina

# Copy compiled JAR from builder
COPY --from=builder /home/ballerina/target/bin/*.jar ./app.jar
COPY config.toml ./

# Expose service port
EXPOSE 9090

# Health check
HEALTHCHECK --interval=20s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:9090/passengers/health || exit 1

# Run the service
CMD ["java", "-jar", "app.jar"]