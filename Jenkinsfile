pipeline {
  agent any
  stages {
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
// TODO: adjust url and tag
    stage('Docker build with docker') {
      steps {
        sh '''docker build -t petclinic:latest .
'''
        sh 'docker tag petclinic acrpetclinic1234.azurecr.io/pet_app:$GIT_COMMIT'
      }
    }
// TODO: adjust repository values
    stage('Docker push to repository') {
      steps {
        sh 'docker images'
        sh 'docker login -u $artifact_repo_USR -p $artifact_repo_PSW acrpetclinic1234.azurecr.io'
        sh 'docker push acrpetclinic1234.azurecr.io/pet_app:$GIT_COMMIT'
      }
    }
  }
  environment {
    artifact_repo = credentials('acr-cred')
    JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64/"
  }
}

