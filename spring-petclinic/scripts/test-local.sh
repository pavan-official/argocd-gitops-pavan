#!/bin/bash
# Script to test Spring PetClinic application locally
# This script builds and runs the application locally for testing

set -e

echo "=========================================="
echo "Testing Spring PetClinic Locally"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Java is installed
if ! command -v java &> /dev/null; then
    echo -e "${RED}Java is not installed. Please install Java 17 or newer.${NC}"
    exit 1
fi

# Check Java version - handle both old (1.8, 1.11) and new (17, 21) formats
JAVA_VERSION_STRING=$(java -version 2>&1 | head -n 1)
# Extract version number from string like: openjdk version "21.0.9"
JAVA_VERSION=$(echo "$JAVA_VERSION_STRING" | sed -n 's/.*version "\([^"]*\)".*/\1/p')

# Extract major version number
if [[ "$JAVA_VERSION" =~ ^1\. ]]; then
    # Old format: 1.8, 1.11, etc.
    JAVA_MAJOR=$(echo "$JAVA_VERSION" | cut -d'.' -f2)
else
    # New format: 17, 21, etc.
    JAVA_MAJOR=$(echo "$JAVA_VERSION" | cut -d'.' -f1)
fi

if [ -z "$JAVA_MAJOR" ] || [ "$JAVA_MAJOR" -lt 17 ]; then
    echo -e "${RED}Java version must be 17 or newer. Current version: ${JAVA_MAJOR:-unknown}${NC}"
    echo -e "${YELLOW}Found: $JAVA_VERSION_STRING${NC}"
    exit 1
fi

echo -e "${GREEN}Java version check passed${NC}"

# Check if Maven wrapper exists
if [ ! -f "./mvnw" ]; then
    echo -e "${RED}Maven wrapper (mvnw) not found. Please run this script from the spring-petclinic directory.${NC}"
    exit 1
fi

# Make mvnw executable
chmod +x ./mvnw

echo -e "${YELLOW}Building application...${NC}"
./mvnw clean package -DskipTests

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Build successful!${NC}"

# Check if JAR file exists
JAR_FILE=$(find target -name "*.jar" -not -name "*-sources.jar" -not -name "*-javadoc.jar" | head -n 1)

if [ -z "$JAR_FILE" ]; then
    echo -e "${RED}JAR file not found in target directory!${NC}"
    exit 1
fi

echo -e "${GREEN}Found JAR: $JAR_FILE${NC}"

# Start the application
echo -e "${YELLOW}Starting application...${NC}"
echo -e "${YELLOW}Application will be available at: http://localhost:8080${NC}"
echo -e "${YELLOW}Actuator endpoints: http://localhost:8080/actuator${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

java -jar "$JAR_FILE"

