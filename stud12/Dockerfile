FROM maven:3.9.9-eclipse-temurin-8 AS builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
COPY WebContent ./WebContent
RUN mvn package -DskipTests
FROM tomcat:9-jre8-temurin-jammy
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=builder /build/target/*.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
