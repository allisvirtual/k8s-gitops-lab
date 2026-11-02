# Build context is demo-api/. Build with:
#   docker build -t demo-api:0.1.0 --build-arg VERSION=0.1.0 demo-api
#
# No HEALTHCHECK on purpose: Kubernetes probes /health instead.

ARG DOTNET_VERSION=9.0

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS build

# What /version will report. Passed in by CI as the tag or commit SHA.
ARG VERSION=0.0.0-dev

WORKDIR /src

# Restore first, in its own layer, so code changes do not re-download packages.
COPY DemoApi/DemoApi.csproj DemoApi/
RUN dotnet restore DemoApi/DemoApi.csproj

COPY DemoApi/ DemoApi/
RUN dotnet publish DemoApi/DemoApi.csproj \
    --configuration Release \
    --no-restore \
    --output /app \
    -p:InformationalVersion=${VERSION}

FROM mcr.microsoft.com/dotnet/aspnet:${DOTNET_VERSION} AS runtime

WORKDIR /app
COPY --from=build /app .

# APP_UID is the non-root user the .NET runtime images provide.
USER $APP_UID

# The .NET 8 and later images already listen on 8080 as a non-root user.
EXPOSE 8080

ENTRYPOINT ["dotnet", "DemoApi.dll"]
