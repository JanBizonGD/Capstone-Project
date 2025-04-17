pipeline {
  agent any
  // tools {
  //   'org.jenkinsci.plugins.docker.commons.tools.DockerTool' '18.09'  
  // }
  stages {
    stage('Display git'){
      steps {
        sh 'echo $GIT_BRANCH_LOCAL'
      }
    }
    stage('Static code analysis') {
      steps {
        sh './gradlew -v'
        sh 'echo $JAVA_HOME'
        sh './gradlew check -x test --stacktrace'
        archiveArtifacts(artifacts: 'src/checkstyle/nohttp-checkstyle.xml', fingerprint: true)
      }
    }
    stage('Java test with Gradle') {
      steps {
        sh './gradlew test'
      }
    }
    stage('Java build with Gradle') {
      steps {
        sh './gradlew build  -x test'
      }
    }
// maybe change to docker compose
    stage('Docker build with docker') {
      steps {
        sh 'docker version'
        sh 'docker build -t petclinic:latest .'
        sh 'docker tag petclinic acrpetclinic1234.azurecr.io/$DEV_REPO:$GIT_COMMIT'
      }
    }
    // TODO: push jar files
  // TODO: install python3-semver
    stage('Docker push to repository') {
      steps {
        sh 'docker images'
        sh 'docker login -u $artifact_repo_USR -p $artifact_repo_PSW acrpetclinic1234.azurecr.io' 
        sh 'docker push acrpetclinic1234.azurecr.io/$DEV_REPO:$GIT_COMMIT'
      }
    }
    stage('Change version') {
      steps {
        sh "env.RELEASE_VERSION=$(pysemver nextver $(sudo ./gradlew -q properties --property version | grep -o 'version.*' | cut -f2 -d' ') minor)"
      }
    }
    stage('Docker push to main') {
      steps {
        sh 'docker login -u $artifact_repo_USR -p $artifact_repo_PSW acrpetclinic1234.azurecr.io' 
        sh 'docker push acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION'
        sh 'git tags $RELEASE_VERSION'
        sh 'git push --tags'
      }
    }
  }
  environment {
    DOCKER_CERT_PATH = credentials('acr-cred')
    artifact_repo = credentials('acr-cred')
    JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64/"
    DEV_REPO="petclinic_dev"
    MAIN_REPO="petclinic"
  }
}

