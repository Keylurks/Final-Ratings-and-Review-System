# ========= Build stage =========
FROM eclipse-temurin:17-jdk AS build

# Install Maven
RUN apt-get update && \
    apt-get install -y maven && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy pom.xml first for dependency caching
COPY pom.xml .

# Download dependencies (this layer will be cached if pom.xml doesn't change)
RUN mvn dependency:go-offline -B

# Copy the rest of the source code
COPY src ./src

# Compile and package the application into a JAR file, skipping tests.
RUN mvn -q -DskipTests package

# ========= Run stage =========
FROM eclipse-temurin:17-jre
WORKDIR /app

# Copy fat jar from build stage
COPY --from=build /app/target/*.jar /app/app.jar

# Health + port
ENV PORT=8081
EXPOSE 8081

# JVM ergonomics for Render
ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxRAMPercentage=75"

# Use production profile by default
ENV SPRING_PROFILES_ACTIVE=prod

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
