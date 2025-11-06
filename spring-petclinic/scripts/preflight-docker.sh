#!/bin/bash
# Preflight checks for Docker build
# This script validates configuration before dockerization

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Docker Preflight Checks"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

# Check 1: Docker is installed
echo -n "Checking Docker installation... "
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✓${NC} Docker found: $DOCKER_VERSION"
else
    echo -e "${RED}✗${NC} Docker is not installed"
    ERRORS=$((ERRORS + 1))
fi

# Check 2: Docker daemon is running
echo -n "Checking Docker daemon... "
if docker info &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker daemon is running"
else
    echo -e "${RED}✗${NC} Docker daemon is not running"
    ERRORS=$((ERRORS + 1))
fi

# Check 3: Dockerfile exists
echo -n "Checking Dockerfile... "
if [ -f "Dockerfile" ]; then
    echo -e "${GREEN}✓${NC} Dockerfile found"
else
    echo -e "${RED}✗${NC} Dockerfile not found"
    ERRORS=$((ERRORS + 1))
fi

# Check 4: .dockerignore exists
echo -n "Checking .dockerignore... "
if [ -f ".dockerignore" ]; then
    echo -e "${GREEN}✓${NC} .dockerignore found"
else
    echo -e "${YELLOW}⚠${NC} .dockerignore not found (not critical, but recommended)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 5: pom.xml exists
echo -n "Checking pom.xml... "
if [ -f "pom.xml" ]; then
    echo -e "${GREEN}✓${NC} pom.xml found"
else
    echo -e "${RED}✗${NC} pom.xml not found (required for Maven build)"
    ERRORS=$((ERRORS + 1))
fi

# Check 6: Source directory exists
echo -n "Checking src directory... "
if [ -d "src" ]; then
    echo -e "${GREEN}✓${NC} src directory found"
else
    echo -e "${RED}✗${NC} src directory not found (required)"
    ERRORS=$((ERRORS + 1))
fi

# Check 7: Java version consistency
echo -n "Checking Java version consistency... "
if [ -f "pom.xml" ] && [ -f "Dockerfile" ]; then
    # Extract Java version from pom.xml (macOS-compatible)
    POM_JAVA=$(grep '<java.version>' pom.xml | sed -n 's/.*<java\.version>\([0-9]*\)<\/java\.version>.*/\1/p' | head -1 || echo "")
    DOCKERFILE_JAVA=$(grep 'eclipse-temurin-' Dockerfile | sed -n 's/.*eclipse-temurin-\([0-9]*\).*/\1/p' | head -1 || echo "")
    
    if [ -z "$POM_JAVA" ]; then
        echo -e "${YELLOW}⚠${NC} Could not extract Java version from pom.xml"
        WARNINGS=$((WARNINGS + 1))
    elif [ -z "$DOCKERFILE_JAVA" ]; then
        echo -e "${YELLOW}⚠${NC} Could not extract Java version from Dockerfile"
        WARNINGS=$((WARNINGS + 1))
    elif [ "$POM_JAVA" = "$DOCKERFILE_JAVA" ]; then
        echo -e "${GREEN}✓${NC} Java versions match (Java $POM_JAVA)"
    else
        echo -e "${RED}✗${NC} Java version mismatch: pom.xml=$POM_JAVA, Dockerfile=$DOCKERFILE_JAVA"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠${NC} Cannot check version consistency (missing files)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 8: Maven wrapper exists (optional but recommended)
echo -n "Checking Maven wrapper... "
if [ -f "mvnw" ]; then
    echo -e "${GREEN}✓${NC} Maven wrapper found"
else
    echo -e "${YELLOW}⚠${NC} Maven wrapper not found (Dockerfile uses Maven image, so this is OK)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 9: Check for build artifacts that should be excluded
echo -n "Checking for build artifacts... "
if [ -d "target" ]; then
    TARGET_SIZE=$(du -sh target 2>/dev/null | cut -f1)
    echo -e "${YELLOW}⚠${NC} target/ directory exists ($TARGET_SIZE) - should be in .dockerignore"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✓${NC} No target/ directory (clean build)"
fi

# Check 10: Verify Dockerfile syntax (basic check)
echo -n "Checking Dockerfile syntax... "
if [ -f "Dockerfile" ]; then
    # Check for common issues
    if grep -q "FROM.*AS.*build" Dockerfile; then
        echo -e "${GREEN}✓${NC} Multi-stage build detected"
    else
        echo -e "${YELLOW}⚠${NC} Not using multi-stage build (may result in larger image)"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Check for health check
    if grep -qi "HEALTHCHECK" Dockerfile; then
        echo -e "${GREEN}✓${NC} Health check configured"
    else
        echo -e "${YELLOW}⚠${NC} No health check configured"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Check 11: Verify .dockerignore excludes unnecessary files
echo -n "Checking .dockerignore contents... "
if [ -f ".dockerignore" ]; then
    if grep -q "target/" .dockerignore; then
        echo -e "${GREEN}✓${NC} target/ is excluded"
    else
        echo -e "${YELLOW}⚠${NC} target/ not in .dockerignore (should be excluded)"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    if grep -q "\.git" .dockerignore; then
        echo -e "${GREEN}✓${NC} .git is excluded"
    else
        echo -e "${YELLOW}⚠${NC} .git not in .dockerignore"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Summary
echo ""
echo "=========================================="
echo "Preflight Check Summary"
echo "=========================================="
echo -e "Errors: ${RED}$ERRORS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ There are $WARNINGS warnings to review${NC}"
    fi
    echo ""
    echo "Ready to proceed with Docker build."
    exit 0
else
    echo -e "${RED}✗ $ERRORS error(s) found. Please fix them before proceeding.${NC}"
    exit 1
fi

