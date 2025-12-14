# ========= Build stage =========
FROM eclipse-temurin:17-jdk AS build

# Install Maven
RUN apt-get update && apt-get install -y maven && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy everything
COPY . .

# Debug: Check source files exist and show directory structure
RUN echo "=== Checking project structure ===" && \
    echo "Current directory:" && pwd && \
    echo "Files in /app:" && ls -la /app/ && \
    echo "=== Checking for pom.xml ===" && \
    test -f /app/pom.xml && echo "✓ pom.xml found" || echo "✗ pom.xml NOT FOUND" && \
    echo "=== Checking source directory ===" && \
    ls -la /app/src/ 2>/dev/null || echo "src/ does not exist" && \
    ls -la /app/src/main/ 2>/dev/null || echo "src/main/ does not exist" && \
    ls -la /app/src/main/java/ 2>/dev/null || echo "src/main/java/ does not exist" && \
    echo "=== Finding Java source files ===" && \
    find /app/src -name "*.java" 2>/dev/null | head -20 || echo "No Java files found"

# Compile - show Maven output
RUN echo "=== Starting Maven compilation ===" && \
    mvn clean compile -DskipTests

# Check what was created after compilation
RUN echo "=== Checking compilation results ===" && \
    echo "Target directory exists:" && test -d /app/target && echo "YES" || echo "NO" && \
    echo "Target contents:" && ls -la /app/target/ 2>/dev/null || echo "target/ does not exist" && \
    echo "Classes directory:" && ls -la /app/target/classes/ 2>/dev/null || echo "target/classes/ does not exist" && \
    echo "Looking for RrsApplication.class:" && \
    find /app/target -name "RrsApplication.class" 2>/dev/null || echo "RrsApplication.class not found"

# Package the application
RUN echo "=== Packaging application ===" && \
    mvn package -DskipTests

# Verify the JAR was created and contains the main class
RUN echo "=== Verifying JAR ===" && \
    ls -la /app/target/*.jar && \
    echo "=== Checking JAR contents for main class ===" && \
    (jar tf /app/target/rrs-0.0.1-SNAPSHOT.jar | grep -q "BOOT-INF/classes/com/example/rrs/RrsApplication.class" && \
     echo "✓ Main class found in BOOT-INF/classes/" || \
     (jar tf /app/target/rrs-0.0.1-SNAPSHOT.jar | grep -q "com/example/rrs/RrsApplication.class" && \
      echo "✓ Main class found in root" || \
      (echo "✗ ERROR: Main class NOT FOUND in JAR!" && \
       echo "JAR structure (first 50 entries):" && \
       jar tf /app/target/rrs-0.0.1-SNAPSHOT.jar | head -50 && \
       echo "Searching for any com/example entries:" && \
       jar tf /app/target/rrs-0.0.1-SNAPSHOT.jar | grep "com/example" | head -10 || echo "No com/example entries" && \
       exit 1)))

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
