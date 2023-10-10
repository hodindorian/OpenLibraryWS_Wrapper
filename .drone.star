def main(ctx):
    pipeline = {
        "kind": "pipeline",
        "name": "myFirstPipeline",
        "steps": []
    };

    build = {
            "name": "build",
            "image": "mcr.microsoft.com/dotnet/sdk:7.0",
            "commands":[
                "cd Sources",
                "dotnet restore OpenLibraryWS_Wrapper.sln",
                "dotnet build OpenLibraryWS_Wrapper.sln -c Release --no-restore",
                "dotnet publish OpenLibraryWS_Wrapper.sln -c Release --no-restore -o $CI_PROJECT_DIR/build/release"
            ]
        };

    pipeline["steps"].append(build);

    tests = {
            "name": "tests",
            "image": "mcr.microsoft.com/dotnet/sdk:7.0",
            "commands":[
                "cd Sources/",
                "dotnet restore OpenLibraryWS_Wrapper.sln",
                "dotnet test OpenLibraryWS_Wrapper.sln --no-restore"
            ],
            "depends_on": ["build"]
        };

    pipeline["steps"].append(tests);

    sonar = {
            "name": "code-inspection",
            "image": "hub.codefirst.iut.uca.fr/marc.chevaldonne/codefirst-dronesonarplugin-dotnet7",
            "settings":{
                "sonar_host": "https://codefirst.iut.uca.fr/sonar/",
                "sonar_token":{
                    "from_secret": "SECRET_SONAR_LOGIN"
                }
            },
            "commands":[
                "cd Sources/",
                "dotnet restore OpenLibraryWS_Wrapper.sln",
                "dotnet sonarscanner begin /k:Dotnet_Dorian_HODIN /d:sonar.host.url=$${PLUGIN_SONAR_HOST} /d:sonar.coverageReportPaths='coveragereport/SonarQube.xml' /d:sonar.coverage.exclusions='Tests/**' /d:sonar.login=$${PLUGIN_SONAR_TOKEN}",
                "dotnet build OpenLibraryWS_Wrapper.sln -c Release --no-restore",
                "dotnet test OpenLibraryWS_Wrapper.sln --logger trx --no-restore /p:CollectCoverage=true /p:CoverletOutputFormat=cobertura --collect 'XPlat Code Coverage'",
                "reportgenerator -reports:'**/coverage.cobertura.xml' -reporttypes:SonarQube -targetdir:'coveragereport'",
                "dotnet publish OpenLibraryWS_Wrapper.sln -c Release --no-restore -o CI_PROJECT_DIR/build/release",
                "dotnet sonarscanner end /d:sonar.login=$${PLUGIN_SONAR_TOKEN}"
            ]
        };

    pipeline["steps"].append(sonar);

    doc = {

            "name": "generate-and-deploy-docs",
            "image": "hub.codefirst.iut.uca.fr/thomas.bellembois/codefirst-docdeployer",
            "failure": "ignore",
            "volumes":{
                "name": "docs",
                "path": "/docs",
            },
            "commands":[
                "/entrypoint.sh"
            ],
            "when":{
                "branch": "master"
            },
            "event": "push",
            "depends_on": ["build,tests"]
        };

    pipeline["steps"].append(doc);

    swagger = {

            "name": "generate-swashbuckle",
            "image": "mcr.microsoft.com/dotnet/sdk:7.0",
            "commands":[
                "cd Sources/OpenLibraryWrapper",
                "dotnet tool install --version 6.5.0 Swashbuckle.AspNetCore.Cli --tool-path /bin",
                "/bin/swagger tofile --output /drone/src/swagger.json bin/Release/net7.0/OpenLibraryWrapper.dll v1"
            ],
            "depends_on": ["build"]
        };

    pipeline["steps"].append(swagger);



    bdd = {

            "name": "deploy-mariadb",
            "image": "hub.codefirst.iut.uca.fr/thomas.bellembois/codefirst-dockerproxy-clientdrone:latest",
            "environment":{
                "IMAGENAME": "mariadb:10",
                "CONTAINERNAME": "db_dotnet",
                "COMMAND": "create",
                "OVERWRITE": "true",
                "PRIVATE": "true",
                "CODEFIRST_CLIENTDRONE_ENV_MARIADB_ROOT_PASSWORD":{
                    "from_secret": "db_root_password"
                },
                "CODEFIRST_CLIENTDRONE_ENV_MARIADB_DATABASE":{
                    "from_secret": "db_database"
                },
                "CODEFIRST_CLIENTDRONE_ENV_MARIADB_USER":{
                    "from_secret": "db_user"
                },
                "CODEFIRST_CLIENTDRONE_ENV_MARIADB_PASSWORD":{
                    "from_secret": "db_password"
                },
            },
            "depends_on": ["deploy-app"]
        };

    pipeline["steps"].append(bdd);

    if ctx.build.branch == "master":
        return pipeline
    else:
        return {}
