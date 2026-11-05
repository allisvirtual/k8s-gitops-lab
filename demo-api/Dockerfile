# Build from the repo root: docker build -t demo-api:0.1.0 --build-arg VERSION=0.1.0 demo-api

ARG DOTNET_VERSION=9.0

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS build

# Reported by /version.
ARG VERSION=0.0.0-dev

WORKDIR /src

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

USER $APP_UID
EXPOSE 8080

ENTRYPOINT ["dotnet", "DemoApi.dll"]
