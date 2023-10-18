# dotnet-sonar

This is a container used to build dotnet projects and provide SonarQube analysis using SonarQube MSBuild Scanner.


----

This latest image was built with the following components:

* dotnetcore-sdk 7.0.401
* SonarQube MSBuild Scanner 5.14.0.78575
* OpenJDK Java Runtime 17 (required by Sonar-Scanner and some Sonar-Scanner plugins)

## Supported tags and respective `Dockerfile` links

> Tags are written using the following pattern: `dotnet-sonar:<year>.<month>.<revision>`

* `23.10.5`, `latest` [(23.10.5/Dockerfile)](https://github.com/thematrix97/dotnet-sonar/blob/23.10.5/Dockerfile)
  * DotNet 7.0.401
  * SonarScanner 5.14.0.78575

## Compiling dotnet code with SonarQube Analysis

Full documentation: <https://docs.sonarqube.org/display/SCAN/Analyzing+with+SonarQube+Scanner+for+MSBuild>

### Inside container

### Using Docker

**Inside container:**

```bash
$ dotnet /sonar-scanner/SonarScanner.MSBuild.dll begin /k:sonarProjectKey
$ dotnet build
$ dotnet /sonar-scanner/SonarScanner.MSBuild.dll end
```

**Configure external SonarQube Server:**

```bash
$ dotnet /sonar-scanner/SonarScanner.MSBuild.dll begin /k:sonarProjectKey /d:sonar.host.url="<SonarQubeServerUrl:Port>" /d:sonar.login="<SonarQubeServerToken>"
$ dotnet build
$ dotnet /sonar-scanner/SonarScanner.MSBuild.dll end  /d:sonar.login="<SonarQubeServerToken>"
```

**Outside container:**

Simple Usage:
```bash
$ docker run -it --rm -v <my-project-source-path>:/source ghcr.io/thematrix97/dotnet-sonar:latest bash -c "cd source \
    && dotnet /sonar-scanner/SonarScanner.MSBuild.dll begin /k:sonarProjectKey /name:sonarProjectName /version:buildVersion \
    && dotnet restore \
    && dotnet build -c Release \
    && dotnet /sonar-scanner/SonarScanner.MSBuild.dll end"
```

Advance Usage:

```bash
$ docker run -it --rm \
    -v <my-project-source-path>:/source \
    -v <my-nugetconfig-source-path>:/nuget \
    dotnet-sonar:latest \
    bash -c \
        "cd source \
        && dotnet /sonar-scanner/SonarScanner.MSBuild.dll begin \
        /k:<ProjectName> /name:<my-project-name> /version:<my-project-version> \
        /d:sonar.host.url="<my-sonar-server-url>" \
        /d:sonar.login="<my-sonar-server-user>" \
        /d:sonar.password="<my-sonar-server-pass>" \
        /d:sonar.cs.opencover.reportsPaths='tests/**/coverage.opencover.xml' \
        && dotnet restore --configfile /nuget/NuGet.Config \
        && dotnet build -c Release \
        && dotnet publish -c Release -r linux-x64 -o deployment \
        && dotnet test --no-build -c Release --filter "Category=Unit" --logger trx --results-directory testResults /p:CollectCoverage=true /    p:CoverletOutputFormat=\"opencover\" \
        && dotnet /sonar-scanner/SonarScanner.MSBuild.dll end \
        /d:sonar.login="<my-sonar-server-user>" \
        /d:sonar.password="<my-sonar-server-pass>""
```

The script above does the following:

* Mounts your project folder to the container's /source folder
* Mounts your nuget config to the container's /nuget folder (optional if no private nuget server is used)
* Begins the sonarscanner with the sonarqube server credentials
* Performs a dotnet restore with the nuget config in /nuget folder
* Executes the build command
* Publishes the build to the deployment folder
* Runs the tests and stores the test results in testResults folder. Change this command to your unit tests needs
* Ends the sonarscanner and publishes the sonarqube analysis results to the sonarqube server

### Using Jenkins pipeline

The following pipeline code will:

* Start a sonar scanning session
* Build dotnet projects
* Run tests with coverage analysis (using coverlet) and publish them using the Jenkins XUnit publisher
* End a sonar scanning session
* [OPTIONAL] In the end, it waits for sonar's quality gate status and sets the build outcome

*Note that in order for coverage analysis to work, you need to add the coverlet NuGet package to the unit test project.*

```groovy
def envVariables = [
    'HOME=/tmp/home',
    'DOTNET_CLI_TELEMETRY_OPTOUT=1'
]

node('somenode-with-docker')
{
    withSonarQubeEnv('my-jenkins-configured-sonar-environment')
    {
        docker.image('ghcr.io/thematrix97/dotnet-sonar:latest').inside()
        {
            withEnv(envVariables)
            {
                stage('build')
                {
                    checkout scm
                    sh "dotnet /sonar-scanner/SonarScanner.MSBuild.dll begin /k:someKey /name:someName /version:someVersion /d:sonar.cs.opencover.reportsPaths='tests/**/coverage.opencover.xml'"
                    sh "dotnet build -c Release /property:Version=someVersion"
                    sh "rm -drf ${env.WORKSPACE}/testResults"
                    sh (returnStatus: true, script: "find tests/**/* -name \'*.csproj\' -print0 | xargs -L1 -0 -P 8 dotnet test --no-build -c Release --logger trx --results-directory ${env.WORKSPACE}/testResults /p:CollectCoverage=true /p:CoverletOutputFormat=opencover")
                    step([$class: 'XUnitPublisher', testTimeMargin: '3000', thresholdMode: 1, thresholds: [[$class: 'FailedThreshold', unstableThreshold: '0']
                            , [$class: 'SkippedThreshold']], tools: [[$class: 'MSTestJunitHudsonTestType', deleteOutputFiles: true, failIfNotNew: false
                            , pattern: 'testResults/**/*.trx', skipNoTestFiles: true, stopProcessingIfError: true]]])
                    sh "dotnet /sonar-scanner/SonarScanner.MSBuild.dll end"
                }
            }
        }
    }
}

timeout(time: 1, unit: 'HOURS')
{
    def qualityGate = waitForQualityGate()
    if (qualityGate.status == 'ERROR')
    {
        currentBuild.result = 'UNSTABLE'
    }
}
```

## Code Coverage

The above examples already implement the code-coverage analysis, **provided you add the coverlet NuGet package to your unit test project**.

If you want to know more, check: <https://dev.to/deinsoftware/net-core-unit-test-and-code-coverage-with-visual-studio-code-37bp>.

Also, coverlet documentation here: <https://github.com/tonerdo/coverlet/>.
