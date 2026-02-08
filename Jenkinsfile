pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "sahilmor16/blue-green"
        KUBE_CONFIG_CREDENTIALS = 'kubeconfig'  // Jenkins secret file with kubeconfig
    }

    stages {

        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/yourusername/blue-green-cicd.git'
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                script {
                    IMAGE_TAG = "v${env.BUILD_NUMBER}" 
                    echo "Building Docker image: ${DOCKER_IMAGE}:${IMAGE_TAG}"
                    sh "docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} ."

                    // Login and push
                    withDockerRegistry(url: 'https://index.docker.io/v1/', credentialsId: 'dockerhub-creds') {
                        sh "docker push ${DOCKER_IMAGE}:${IMAGE_TAG}"
                        sh "docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${DOCKER_IMAGE}:latest"
                        sh "docker push ${DOCKER_IMAGE}:latest"
                    }
                }
            }
        }


        stage('Determine Live Deployment') {
            steps {
                withCredentials([file(credentialsId: "${KUBE_CONFIG_CREDENTIALS}", variable: 'KUBECONFIG')]) {
                    script {
                        CURRENT_VERSION = sh(
                            script: "kubectl get svc myapp-service -o jsonpath='{.spec.selector.version}'",
                            returnStdout: true
                        ).trim()

                        if (CURRENT_VERSION == "blue") {
                            LIVE = "blue"
                            STANDBY = "green"
                        } else {
                            LIVE = "green"
                            STANDBY = "blue"
                        }

                        echo "Current live deployment: ${LIVE}"
                        echo "Standby deployment for new version: ${STANDBY}"
                    }
                }
            }
        }

        stage('Deploy New Version to Standby') {
            steps {
                withCredentials([file(credentialsId: "${KUBE_CONFIG_CREDENTIALS}", variable: 'KUBECONFIG')]) {
                    script {
                        echo "Deploying ${STANDBY}-app with image ${DOCKER_IMAGE}:${IMAGE_TAG}"
                        sh """
                        kubectl set image deployment/${STANDBY}-app app=${DOCKER_IMAGE}:${IMAGE_TAG} --record
                        """
                    }
                }
            }
        }

        stage('Health Check Standby') {
            steps {
                withCredentials([file(credentialsId: "${KUBE_CONFIG_CREDENTIALS}", variable: 'KUBECONFIG')]) {
                    script {
                        try {
                            sh "kubectl rollout status deployment/${STANDBY}-app --timeout=120s"
                            HEALTHY = true
                        } catch(err) {
                            HEALTHY = false
                        }
                    }
                }
            }
        }

        stage('Switch Traffic to Standby') {
            when {
                expression { return HEALTHY == true }
            }
            steps {
                withCredentials([file(credentialsId: "${KUBE_CONFIG_CREDENTIALS}", variable: 'KUBECONFIG')]) {
                    script {
                        echo "Switching traffic to ${STANDBY}-app"
                        sh """
                        kubectl patch service myapp-service \
                        -p '{\"spec\":{\"selector\":{\"app\":\"myapp\",\"version\":\"${STANDBY}\"}}}'
                        """
                    }
                }
            }
        }

        stage('Rollback on Failure') {
            when {
                expression { return HEALTHY == false }
            }
            steps {
                script {
                    echo "Deployment failed, rolling back to ${LIVE}-app"
                    withCredentials([file(credentialsId: "${KUBE_CONFIG_CREDENTIALS}", variable: 'KUBECONFIG')]) {
                        sh """
                        kubectl patch service myapp-service \
                        -p '{\"spec\":{\"selector\":{\"app\":\"myapp\",\"version\":\"${LIVE}\"}}}'
                        """
                    }
                }
            }
        }
    }
}
