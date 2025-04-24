pipeline {
  agent any
  stages {
  //   stage('Approve') {
  //     when {
  //       expression {
  //           return "$GIT_BRANCH" == 'origin/main';
  //       }
  //     }
  //     steps {
  //       input(message: 'Would you like to deploy?')
  //     }
  //   }
    stage('Load variables'){
      steps {
        copyArtifacts(
            projectName: 'Infrastructure',
            filter: 'deploy-info.txt',
            target: 'Infrastructure',
            flatten: true
        )
        script {
          def props = readProperties file: 'Infrastructure/deploy-info.txt'
          echo "IPs: ${props.IPs}"
          echo "Host name: ${props.URIs}"
          def conv_ips = props.IPs.replace('[', '').replace(']', '').replace(' ', '').replace('"', '')
          echo "Converted IPs: ${conv_ips}"
          def lb_ip = props.LB_IP

          def descriptionText = "🚀 Deployed to <a href='http://${lb_ip}'>http://${lb_ip}</a>"
          Jenkins.instance.getItem("DeployProject").setDescription(descriptionText)

          env.VM_LIST = conv_ips
          env.MYSQL_HOST = "jdbc:mysql://${props.URIs}:3306/${env.database}"
        }
      }
    }
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
      }
    }
    stage('Java test with Gradle') {
      steps {
        sh './gradlew test'
        archiveArtifacts(artifacts: 'build/reports/tests/test/*', fingerprint: true)
      }
    }
    stage('Java build with Gradle') {
      steps {
        sh './gradlew build  -x test'
      }
    }
    stage('Docker build with docker') {
      steps {
        sh 'docker version'
        sh 'docker build -t petclinic:latest .'
        sh 'docker tag petclinic acrpetclinic1234.azurecr.io/$DEV_REPO:$GIT_COMMIT'
      }
    }
    // TODO: push jar files
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
        expression {
            return "$GIT_BRANCH" == 'origin/main';
        }
      }
      steps {
        sh 'docker login -u $artifact_repo_USR -p $artifact_repo_PSW acrpetclinic1234.azurecr.io'
        sh 'docker tag petclinic acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION'
        sh 'docker push acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION'
        // TODO: check if tag already exist
        sh 'git tag $RELEASE_VERSION || true'
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
        script {
          currentBuild.rawBuild.setDescription('Would you like to deploy?') 
        }
        //input (message: 'Would you like to deploy?')
        sh 'ansible all --become-method sudo -b -i $VM_LIST, -u $deployment_group_cred_USR --extra-vars "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker rm -f petclinic || true"'
        sh 'ansible all --become-method sudo -b -i $VM_LIST, -u $deployment_group_cred_USR --extra-vars "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker images $MAIN_REPO -q | xargs docker rmi -f || true"'
        sh 'ansible all --become-method sudo -b -i $VM_LIST, -u $deployment_group_cred_USR --extra-vars "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker login -u $artifact_repo_USR -p $artifact_repo_PSW acrpetclinic1234.azurecr.io"'
        sh 'ansible all --become-method sudo -b -i $VM_LIST, -u $deployment_group_cred_USR --extra-vars "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker pull acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION"'
        //sh 'ansible all --become-method sudo -b -i $VM_LIST, -u $deployment_group_cred_USR --extra-vars "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker run -d --name petclinic -p 80:8080 acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION"'
        sh 'ansible all --become-method sudo -b -i $VM_LIST, -u $deployment_group_cred_USR --extra-vars "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker run -d --name petclinic -e MYSQL_HOST=$MYSQL_HOST -e MYSQL_USER=$MYSQL_USER -e MYSQL_PASS=$MYSQL_PASS -p 80:8080 acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION"'
        script {
          currentBuild.rawBuild.setDescription('🚀')
        }

//ansible all -i <vm_ip>, -u <user> -m shell -a "docker run -d --name myapp -e DB_HOST=<mysql_host> -e DB_USER=<user> -e DB_PASS=<pass> -p 80:80 <registry_url>/myapp:latest"
// TODO: connect to sql database
      }
      environment {
            deployment_group_cred = credentials('deploy-group-cred')
            ANSIBLE_HOST_KEY_CHECKING='False'
      }
    }
  }
  environment {
    DOCKER_CERT_PATH = credentials('acr-cred')
    artifact_repo = credentials('acr-cred')
    JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64/"
    DEV_REPO="petclinic_dev"
    MAIN_REPO="petclinic"
    SPRING_PROFILES_ACTIVE="mysql"

    MYSQL_USER="azureuser"
    MYSQL_PASS="Password123!"
    database="petclinicdb"
  }
}
//
