FROM openjdk:8u151-stretch

RUN apt-get update
RUN apt-get -y install maven

