FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY LEDOANVANTU2.Api.csproj ./
RUN dotnet restore LEDOANVANTU2.Api.csproj
COPY . ./
RUN dotnet publish LEDOANVANTU2.Api.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:10000
EXPOSE 10000
COPY --from=build /app/publish ./
ENTRYPOINT ["dotnet", "LEDOANVANTU2.Api.dll"]
