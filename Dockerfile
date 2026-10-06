#deploy JAVA application

FROM maven:3.10.0-eclipse-temurin-17 AS builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn package -DskipTests
FROM tomcat:9-jre8-temurin-jammy
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=builder /build/target/java_chess.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080