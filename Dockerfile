# ========= Build stage =========
FROM eclipse-temurin:17-jdk AS build

# Install Maven
RUN apt-get update && apt-get install -y maven && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy everything
COPY . .

# Debug: Check source files exist
RUN echo "=== Checking source files ===" && find /app/src -name "*.java" | head -10

# Compile - show output to see any errors
RUN echo "=== Starting Maven compilation ===" && mvn clean compile -DskipTests

# Check what was created after compilation - verify classes exist
RUN echo "=== Checking compilation results ===" && \
    ls -la /app/target/ 2>/dev/null || echo "target directory does not exist" && \
    echo "=== Verifying RrsApplication.class was compiled ===" && \
    test -f /app/target/classes/com/example/rrs/RrsApplication.class && \
    echo "✓ RrsApplication.class found in target/classes!" || \
    (echo "✗ ERROR: RrsApplication.class NOT FOUND after compilation!" && \
     echo "Listing target/classes structure:" && \
     find /app/target/classes -type f 2>/dev/null | head -20 || echo "No files in target/classes" && \
     exit 1)

# Package the application
RUN mvn package -DskipTests

# Verify the JAR was created and contains the main class - FAIL BUILD if not found
RUN echo "=== Verifying JAR contains main class ===" && \
    ls -la /app/target/*.jar && \
    if jar tf /app/target/rrs-0.0.1-SNAPSHOT.jar | grep -q "BOOT-INF/classes/com/example/rrs/RrsApplication.class"; then \
        echo "✓ Main class found in BOOT-INF/classes/"; \
    elif jar tf /app/target/rrs-0.0.1-SNAPSHOT.jar | grep -q "com/example/rrs/RrsApplication.class"; then \
        echo "✓ Main class found in root"; \
    else \
        echo "✗ ERROR: Main class NOT FOUND in JAR!"; \
        echo "JAR structure (first 50 entries):"; \
        jar tf /app/target/rrs-0.0.1-SNAPSHOT.jar | head -50; \
        echo "Searching for any com/example entries:"; \
        jar tf /app/target/rrs-0.0.1-SNAPSHOT.jar | grep "com/example" | head -10 || echo "No com/example entries found"; \
        echo "Checking BOOT-INF structure:"; \
        jar tf /app/target/rrs-0.0.1-SNAPSHOT.jar | grep "BOOT-INF" | head -10 || echo "No BOOT-INF found"; \
        echo "Checking if classes directory exists:"; \
        ls -la /app/target/classes/com/example/rrs/ 2>/dev/null || echo "Classes not in expected location"; \
        exit 1; \
    fi

# Verify classes were compiled
RUN echo "=== Checking if classes were compiled ===" && \
    ls -la /app/target/classes/com/example/rrs/ 2>/dev/null || \
    (echo "Classes directory check:" && \
     find /app/target -name "*.class" | head -10 || echo "No class files found")

# Find and copy the Spring Boot JAR (not the .original one) to a known location
RUN find /app/target -name "rrs-*.jar" ! -name "*.original" -type f -exec cp {} /app/app.jar \;

# ========= Run stage =========
FROM eclipse-temurin:17-jre
WORKDIR /app

# Copy fat jar from build stage
COPY --from=build /app/app.jar /app/app.jar

# Health + port
ENV PORT=8081
EXPOSE 8081

# JVM ergonomics for Render
ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxRAMPercentage=75"

# Use production profile by default
ENV SPRING_PROFILES_ACTIVE=prod

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
