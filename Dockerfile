# ========================
# 1. BUILD STAGE
# Used to compile and package the Java application.
# ========================
FROM eclipse-temurin:17-jdk AS build

# Set the working directory inside the container
WORKDIR /app

# Install Maven and combine with cleanup commands into one layer for efficiency.
RUN apt-get update && \
    apt-get install -y maven && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy the source code and build files into the build stage.
# We copy pom.xml first to allow Docker to cache the dependencies layer.
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy the rest of the source code
COPY src src/

# Compile and package the application into a JAR file, skipping tests.
# The JAR will be in /app/target/
RUN mvn -q -DskipTests package


# ========================
# 2. RUN STAGE
# Used to run the application with the much smaller JRE.
# ========================
FROM eclipse-temurin:17-jre

# Set the working directory for the final application
WORKDIR /app

# Copy the packaged JAR file from the 'build' stage
# The name pattern is often '*-SNAPSHOT.jar' or '*-0.0.1-SNAPSHOT.jar'
COPY --from=build /app/target/*.jar /app/app.jar

# Define port and expose it
ENV PORT=8081
EXPOSE 8081

# JVM ergonomics for Render or other cloud providers
ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxRAMPercentage=75"

# Use production profile by default (standard Spring Boot config)
ENV SPRING_PROFILES_ACTIVE=prod

# Define the command to run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
COPY --from=build /workspace/target/*.jar /app/app.jar

# Health + port
ENV PORT=8081
EXPOSE 8081

# JVM ergonomics for Render
ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxRAMPercentage=75"

# Use production profile by default
ENV SPRING_PROFILES_ACTIVE=prod

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
