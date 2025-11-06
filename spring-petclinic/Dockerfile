# Multi-stage build for Spring PetClinic application
# Note: We use a pre-built JAR to avoid ErrorProne compatibility issues in Docker
# Build the JAR locally first: ./mvnw clean package -DskipTests
# Then copy the JAR into the image

# Runtime image
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Install wget for health checks
RUN apt-get update && apt-get install -y --no-install-recommends wget && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r spring && useradd -r -g spring spring

# Copy pre-built JAR from local build
# Build locally first: ./mvnw clean package -DskipTests
COPY target/spring-petclinic-*.jar app.jar

# Change ownership to non-root user
RUN chown spring:spring app.jar

# Switch to non-root user
USER spring:spring

# Expose application port
EXPOSE 8080

# Health check - install wget for health checks (or use curl if available)
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]

