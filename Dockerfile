# ========= Build stage =========
FROM eclipse-temurin:17-jdk AS build

# Install Maven
RUN apt-get update && \
    apt-get install -y maven && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy everything (pom.xml and src directory)
COPY . .

# Debug: Check source files exist
RUN echo "=== Checking source files ===" && \
    find /app/src -name "*.java" | head -10 && \
    ls -la /app/src/main/java/com/example/rrs/ || echo "Source directory not found"

# Compile with output to see what's happening (remove -q to see errors)
RUN mvn clean compile -DskipTests || \
    (echo "=== Compilation failed, showing errors ===" && \
     mvn clean compile -e -DskipTests && \
     exit 1)

# Verify classes were compiled
RUN test -f /app/target/classes/com/example/rrs/RrsApplication.class || \
    (echo "ERROR: RrsApplication.class not found after compilation" && \
     echo "Checking target directory:" && \
     ls -la /app/target/ 2>/dev/null || echo "target directory does not exist" && \
     echo "Checking classes directory:" && \
     ls -la /app/target/classes/ 2>/dev/null || echo "target/classes does not exist" && \
     find /app -name "*.class" 2>/dev/null | head -10 && \
     exit 1)

# Package the application
RUN mvn package -q -DskipTests

# Verify the JAR was created and contains classes (Spring Boot puts classes in BOOT-INF/classes/)
RUN ls -la /app/target/*.jar && \
    (jar tf /app/target/rrs-*.jar | grep -q "BOOT-INF/classes/com/example/rrs/RrsApplication.class" || \
     jar tf /app/target/rrs-*.jar | grep -q "com/example/rrs/RrsApplication.class") || \
    (echo "ERROR: Main class not found in JAR. Checking JAR structure:" && \
     echo "JAR files:" && ls -la /app/target/*.jar && \
     echo "First 50 entries in JAR:" && jar tf /app/target/rrs-*.jar | head -50 && \
     exit 1)

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
