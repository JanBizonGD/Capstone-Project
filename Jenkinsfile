pipeline {
  agent any
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
        sh './gradlew check -x test -x compileTestJava -x processTestResources -x testClasses -x processTestAot -x compileAotTestJava -x processAotTestResources -x aotTestClasses'
        archiveArtifacts(artifacts: 'build/reports/checkstyleNohttp/nohttp.html', fingerprint: true)
      }
    }
    stage('Java test with Gradle') {
      steps {
        sh './gradlew test'
      }
    }
    stage('Java build with Gradle') {
      when {
        expression { params.Type == 'Gradle' }
      }
      steps {
        sh './gradlew build  -x test -x compileTestJava -x processTestResources -x testClasses -x processTestAot -x compileAotTestJava -x processAotTestResources -x aotTestClasses'
      }
    }
    stage('Docker build with docker') {
      when {
        expression { params.Type == 'Docker' }
      }
      steps {
        sh 'docker version'
        sh 'docker build -t petclinic:latest .'
        sh 'docker tag petclinic acrpetclinic1234.azurecr.io/$DEV_REPO:$GIT_COMMIT'
      }
    }
    // TODO: push jar files
    stage('Docker push to repository') {
      when {
        expression { params.Type == 'Docker' }
      }
      steps {
        sh 'docker images'
        sh 'docker login -u $artifact_repo_USR -p $artifact_repo_PSW acrpetclinic1234.azurecr.io' 
        sh 'docker push acrpetclinic1234.azurecr.io/$DEV_REPO:$GIT_COMMIT'
      }
    }
    stage('Change version') {
      when {
        expression {
            return "$GIT_BRANCH" == 'origin/main';
        }
      }
      steps {
        script {
         env.RELEASE_VERSION = sh(script: 'pysemver nextver $(sudo ./gradlew -q properties --property version | grep -o \'version.*\' | cut -f2 -d\' \' | tr -d "\'") minor', returnStdout: true).trim()
        }
      }
    }
    stage('Docker push to main') {
      when {
        expression {
            return "$GIT_BRANCH" == 'origin/main' && params.Type == 'Docker';
        }
      }
      steps {
        sh 'docker login -u $artifact_repo_USR -p $artifact_repo_PSW acrpetclinic1234.azurecr.io'
        sh 'docker tag petclinic acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION'
        sh 'docker push acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION'
        sh 'git tag $RELEASE_VERSION || true'
        sh 'echo ${GITHUB_TOKEN}'
        withCredentials([string(credentialsId: 'github-token', variable: 'GH_TOKEN')]) {
          sh 'git remote set-url origin https://${GH_TOKEN}@github.com/JanBizonGD/Capstone-Project.git'
        }
        sh 'echo "version = \'$RELEASE_VERSION\'\n" > gradle.properties'
        sh 'git add gradle.properties'
        sh 'git commit -m "AUTO version increase"'
        sh 'git push --tags origin HEAD:main'
      }
    }
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
          //echo "IPs: ${props.IPs}"
          //echo "Host name: ${props.URIs}"


          def descriptionText = "🚀 Deployed to <a href='http://${props.LB_IP}'>http://${props.LB_IP}</a>"
          Jenkins.instance.getItem("DeployProject").setDescription(descriptionText)
          env.LB_IP = props.LB_IP
          env.MYSQL_URL = "jdbc:mysql://${env.url}:3306/${env.database}"
        }
      }
      environment{
            database="petclinicdb"
            url="petclinic-sqlserver.privatelink.mysql.database.azure.com"
      }
    }
    stage('Docker deploy') {
      when {
        expression {
            return "$GIT_BRANCH" == 'origin/main' && params.Deploy == true  && params.Type == 'Docker';
        }
      }
      steps {
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50001" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker rm -f petclinic || true"'
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50001" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker images $MAIN_REPO -q | xargs -I {} docker rmi -f {} || true"'
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50001" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker login -u $artifact_repo_USR -p $artifact_repo_PSW acrpetclinic1234.azurecr.io"'
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50001" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker pull acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION"'
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50001" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker run -d --name petclinic -e MYSQL_URL=$MYSQL_URL -e MYSQL_USER=$MYSQL_USER -e MYSQL_PASS=$MYSQL_PASS -e MYSQL_DATABASE=petclinic -p 80:8080 acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION"'
        
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50002" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker rm -f petclinic || true"'
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50002" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker images $MAIN_REPO -q | xargs -I {} docker rmi -f {} || true"'
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50002" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker login -u $artifact_repo_USR -p $artifact_repo_PSW acrpetclinic1234.azurecr.io"'
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50002" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker pull acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION"'
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50002" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker run -d --name petclinic -e MYSQL_URL=$MYSQL_URL -e MYSQL_USER=$MYSQL_USER -e MYSQL_PASS=$MYSQL_PASS -e MYSQL_DATABASE=petclinic -p 80:8080 acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION"'
        
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50003" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker rm -f petclinic || true"'
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50003" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker images $MAIN_REPO -q | xargs -I {} docker rmi -f {} || true"'
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50003" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker login -u $artifact_repo_USR -p $artifact_repo_PSW acrpetclinic1234.azurecr.io"'
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50003" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker pull acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION"'
        sh 'ansible all --become-method sudo -b -i $LB_IP, -u $deployment_group_cred_USR -e "ansible_port=50003" -e "ansible_password=$deployment_group_cred_PSW" -m shell -a "docker run -d --name petclinic -e MYSQL_URL=$MYSQL_URL -e MYSQL_USER=$MYSQL_USER -e MYSQL_PASS=$MYSQL_PASS -e MYSQL_DATABASE=petclinic -p 80:8080 acrpetclinic1234.azurecr.io/$MAIN_REPO:$RELEASE_VERSION"'
      
        script {
          currentBuild.rawBuild.setDescription('🚀')
        }
      }
      environment {
        deployment_group_cred = credentials('vm-cred')
        ANSIBLE_HOST_KEY_CHECKING='False'
        SQL_CRED = credentials('db-cred')
        MYSQL_USER="$SQL_CRED_USR"
        MYSQL_PASS="$SQL_CRED_PSW"

        SPRING_PROFILES_ACTIVE="mysql"
      }
    }
  }
  post {
    always {
      archiveArtifacts(artifacts: 'build/reports/tests/test/**/*', fingerprint: true, onlyIfSuccessful: false)
    }
  }
  environment {
    artifact_repo = credentials('acr-cred')
    
    JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64/"
    DEV_REPO="petclinic_dev"
    MAIN_REPO="petclinic"
  }
}

