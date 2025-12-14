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

# Check what was created
RUN echo "=== Checking compilation results ===" && ls -la /app/target/ 2>/dev/null || echo "target directory does not exist"

# Package the application
RUN mvn package -DskipTests

# Verify the JAR was created
RUN ls -la /app/target/*.jar

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

