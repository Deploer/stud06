#deploy JAVA application

FROM maven:3.9.9-eclipse-temurin-17 AS builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn --batch-mode package -DskipTests
FROM tomcat:9.0-jre8-temurin
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=builder /build/target/chess-1.0.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080