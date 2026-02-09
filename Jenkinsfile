pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "sahilmor16/blue-green"
        KUBE_CONFIG_CREDENTIALS = "kubeconfig"   // Jenkins secret file
    }

    stages {

        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/sahilmor16/blue-green.git'
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                script {
                    IMAGE_TAG = "v${env.BUILD_NUMBER}"
                    echo "Building Docker image: ${DOCKER_IMAGE}:${IMAGE_TAG}"

                    bat "docker build -t ${DOCKER_IMAGE}:${IMAGE_TAG} ."

                    withDockerRegistry(
                        url: 'https://index.docker.io/v1/',
                        credentialsId: 'dockerhub-creds'
                    ) {
                        bat "docker push ${DOCKER_IMAGE}:${IMAGE_TAG}"
                        bat "docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${DOCKER_IMAGE}:latest"
                        bat "docker push ${DOCKER_IMAGE}:latest"
                    }
                }
            }
        }

        stage('Determine Live Deployment') {
            steps {
                withCredentials([
                    file(credentialsId: "${KUBE_CONFIG_CREDENTIALS}", variable: 'KUBECONFIG')
                ]) {
                    script {
                        def CURRENT_VERSION = powershell(
                            script: '''
                            kubectl get svc myapp-service ^
                            -o jsonpath="{.spec.selector.version}"
                            ''',
                            returnStdout: true
                        ).trim()
                        
                        echo "Service selector version = ${CURRENT_VERSION}"

                        if (CURRENT_VERSION == "blue") {
                            env.LIVE = "blue"
                            env.STANDBY = "green"
                        } else if (CURRENT_VERSION == "green") {
                            env.LIVE = "green"
                            env.STANDBY = "blue"
                        } else {
                            error "Unknown service version: ${CURRENT_VERSION}"
                        }

                        echo "LIVE deployment    : ${env.LIVE}"
                        echo "STANDBY deployment : ${env.STANDBY}"
                    }
                }
            }
        }

        stage('Deploy New Version to Standby') {
            steps {
                withCredentials([
                    file(credentialsId: "${KUBE_CONFIG_CREDENTIALS}", variable: 'KUBECONFIG')
                ]) {
                    script {
                        echo "Deploying ${STANDBY} with ${DOCKER_IMAGE}:${IMAGE_TAG}"

                        bat """
                        kubectl set image deployment/${env.STANDBY}-app ^
                        app=${DOCKER_IMAGE}:${IMAGE_TAG} --record
                        """
                    }
                }
            }
        }

        stage('Health Check Standby') {
            steps {
                withCredentials([
                    file(credentialsId: "${KUBE_CONFIG_CREDENTIALS}", variable: 'KUBECONFIG')
                ]) {
                    script {
                        env.HEALTHY = false
                        try {
                            bat "kubectl rollout status deployment/${env.STANDBY}-app --timeout=120s"
                            env.HEALTHY = true
                        } catch (err) {
                            echo "Health check failed"
                        }
                    }
                }
            }
        }

        stage('Switch Traffic to Standby') {
            when {
                expression { env.HEALTHY == true }
            }
            steps {
                withCredentials([
                    file(credentialsId: "${KUBE_CONFIG_CREDENTIALS}", variable: 'KUBECONFIG')
                ]) {
                    script {
                        echo "Switching traffic to ${env.STANDBY}"

                        bat """
                        kubectl patch service myapp-service ^
                        -p "{\\"spec\\":{\\"selector\\":{\\"app\\":\\"myapp\\",\\"version\\":\\"${env.STANDBY}\\"}}}"
                        """
                    }
                }
            }
        }

        stage('Rollback on Failure') {
            when {
                expression { env.HEALTHY == false }
            }
            steps {
                withCredentials([
                    file(credentialsId: "${KUBE_CONFIG_CREDENTIALS}", variable: 'KUBECONFIG')
                ]) {
                    script {
                        echo "Rollback → switching back to ${env.LIVE}"

                        bat """
                        kubectl patch service myapp-service ^
                        -p "{\\"spec\\":{\\"selector\\":{\\"app\\":\\"myapp\\",\\"version\\":\\"${env.LIVE}\\"}}}"
                        """
                    }
                }
            }
        }
    }
}
