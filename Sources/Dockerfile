FROM mcr.microsoft.com/dotnet/sdk:7.0 as build-env
COPY . .
RUN dotnet restore OpenLibraryWS_Wrapper.sln
RUN dotnet publish -c Release -o /publish

FROM mcr.microsoft.com/dotnet/aspnet:7.0 as runtime
WORKDIR /publish
COPY --from=build-env /publish .
EXPOSE 80
ENTRYPOINT ["dotnet", "OpenLibraryWrapper.dll"]
