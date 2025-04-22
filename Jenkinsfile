pipeline {
  agent any
  // tools {
  //   'org.jenkinsci.plugins.docker.commons.tools.DockerTool' '18.09'  
  // }
  stages {
    stage('Display branch'){
      steps {
        sh 'echo Current branch: $GIT_BRANCH'
      }
    }
    stage('Static code analysis') {
      steps {
        sh './gradlew -v'
        sh 'echo $JAVA_HOME'
        sh './gradlew check -x test --stacktrace'
        archiveArtifacts(artifacts: 'build/reports/checkstyleNohttp/nohttp.html', fingerprint: true)
        archiveArtifacts(artifacts: 'build/reports/tests/test/*', fingerprint: true)
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
      when {
        //branch 'origin/main'
        expression {
            return "$GIT_BRANCH" == 'origin/main';
        }
      }
      steps {
        script {
         env.RELEASE_VERSION = sh(script: 'pysemver nextver $(sudo ./gradlew -q properties --property version | grep -o \'version.*\' | cut -f2 -d\' \') minor', returnStdout: true).trim()
        }
      }
    }
    stage('Docker push to main') {
      when {
        //branch 'origin/main'
        expression {
            return "$GIT_BRANCH" == 'origin/main';
        }
      }
      steps {
        sh 'docker login -u $artifact_repo_USR -p $artifact_repo_PSW acrpetclinic1234.azurecr.io'
        sh 'docker tag petclinic acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION'
        sh 'docker push acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION'
        sh 'git tag $RELEASE_VERSION'
        //sh 'git push --tags'
        // TODO: Credentials
      }
    }
    stage('Deploy') {
      when {
        expression {
            return "$GIT_BRANCH" == 'origin/main';
        }
      }
      steps {
        input message: 'Would you like to deploy?', ok: 'Yes', cancel: 'No'
        sh 'ansible all -i $VM_LIST, -u $deployment_group_cred_USR --extra-vars "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker rm -f petclinic || true && docker rmi $MAIN_REPO:latest || true"'
        sh 'ansible all -i $VM_LIST, -u $deployment_group_cred_USR --extra-vars "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker pull acrpetclinic1234.azurecr.io/$MAIN_REPO:latest"'
        sh 'ansible all -i $VM_LIST, -u $deployment_group_cred_USR --extra-vars "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker run -d --name petclinic -p 8080:8080 acrpetclinic1234.azurecr.io/$MAIN_REPO:latest"'
//ansible all -i <vm_ip>, -u <user> -m shell -a "docker run -d --name myapp -e DB_HOST=<mysql_host> -e DB_USER=<user> -e DB_PASS=<pass> -p 80:80 <registry_url>/myapp:latest"
// TODO: Display link
// TODO: connect to sql database
      }
      environment {
            deployment_group_cred = credentials('deploy-group-cred')
            VM_LIST="10.1.2.5,10.1.2.6,10.1.2.7"
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

