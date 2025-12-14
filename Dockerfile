# ========= Build stage =========
FROM eclipse-temurin:17-jdk AS build
WORKDIR /workspace

# Install Maven
RUN apt-get update && \
    apt-get install -y maven && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy entire context (optimized by .dockerignore) and build
COPY . .
RUN mvn -q -DskipTests package

# ========= Run stage =========
FROM eclipse-temurin:17-jre
WORKDIR /app

# Copy fat jar
COPY --from=build /workspace/target/*.jar /app/app.jar

# Health + port
ENV PORT=8081
EXPOSE 8081

# JVM ergonomics for Render
ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxRAMPercentage=75"

# Use production profile by default
ENV SPRING_PROFILES_ACTIVE=prod

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
