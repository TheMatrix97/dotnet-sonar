FROM mcr.microsoft.com/dotnet/sdk:7.0.401-alpine3.18

# Dockerfile meta-information
LABEL maintainer="TheMatrix97" \
    app_name="dotnet-sonar"

ENV SONAR_SCANNER_MSBUILD_VERSION=5.14.0.78575 \
    DOTNETCORE_SDK=7.0.401 \
    DOTNETCORE_RUNTIME=7.0.11 \
    NETAPP_VERSION=net5.0

# Linux update
RUN apk --no-cache add \
        unzip \
        openjdk17-jre

# Install Sonar Scanner
RUN wget https://github.com/SonarSource/sonar-scanner-msbuild/releases/download/$SONAR_SCANNER_MSBUILD_VERSION/sonar-scanner-msbuild-$SONAR_SCANNER_MSBUILD_VERSION-$NETAPP_VERSION.zip \
    && unzip sonar-scanner-msbuild-$SONAR_SCANNER_MSBUILD_VERSION-$NETAPP_VERSION.zip -d /sonar-scanner \
    && rm sonar-scanner-msbuild-$SONAR_SCANNER_MSBUILD_VERSION-$NETAPP_VERSION.zip \
    && chmod +x -R /sonar-scanner
