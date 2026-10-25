pipeline {
  agent {

    docker {
      image 'devcvs-srv01:5000/shop2-backend/jenkins-agent'
    }

  }

  stages {

    stage('Copy source with configs') {
      steps {
        git(url: 'http://cvs.tinkoff-dbs1.west.com/backendsbox/shop2.backend.git', branch: 'backend1-staging', poll: true, credentialsId: 'git')
        sh 'ssh-keyscan -H devbuild-srv01 >> ~/.ssh/known_hosts'
        sh 'scp jenkins@devbuild-srv01:/home/jenkins/build/configs/staging/gateway-api/application-business-config-defaults.yml gateway-api/src/main/resources/application-business-config-defaults.yml'
      }
    }

    stage('Build jar') {
      steps {
        sh 'gradle bootRepackage'
      }
    }

    stage('Make docker image') {
      steps {
        sh 'cp -R gateway-api/build/libs/* docker-setup/shop/gateway-api && cd docker-setup/shop/gateway-api && docker build --tag=gateway-api .'
        sh '''docker tag gateway-api devcvs-srv01:5000/shop2-backend/gateway-api:2-staging && docker push devcvs-srv01:5000/shop2-backend/gateway-api:2-staging'''

      }
    }

    stage('Run docker on devbe-srv01') {
      steps {
        sh 'ssh-keyscan -H devbe-srv01 >> ~/.ssh/known_hosts'
        sh '''ssh jenkins@devbe-srv01 << EOF
	sudo docker pull devcvs-srv01:5000/shop2-backend/gateway-api:2-staging
	cd /etc/shop/docker
	sudo docker-compose up -d
EOF'''
      }
    }
  }
  triggers {
    pollSCM('*/1 H * * *')
  }
}