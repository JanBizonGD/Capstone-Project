pipeline {
  agent any
  stages {
    stage('Static code analysis') {
      steps {
        sh '''./gradlew check -x test 
'''
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
        sh 'docker tag petclinic host.docker.internal:9902/mr:$GIT_COMMIT'
      }
    }
// TODO: adjust repository values
    stage('Docker push to repository') {
      steps {
        sh 'docker images'
        sh 'docker login -u $artifact_repo_USR -p $artifact_repo_PSW http://host.docker.internal:9902'
        sh 'docker push host.docker.internal:9902/mr:$GIT_COMMIT'
      }
    }
  }
  environment {
    artifact_repo = credentials('artifact-repo')
  }
}
//
