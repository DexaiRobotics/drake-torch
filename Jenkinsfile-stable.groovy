pipeline {
    environment {
        registry = "dexai2/drake-torch"
        registryCredential = 'dockerhub'
    }
    agent any
    options {
        parallelsAlwaysFailFast()
    }
    stages {

        stage('build_images') {
            parallel {
                stage('build_cuda') {
                    steps {
                        echo "starting in $PWD"
                        sh "cd $WORKSPACE"
                        sh "ls"
                        sh "./build.sh --cuda --stable"
                    }
                }
                stage('build_cpu') {
                    steps {
                        echo "starting in $PWD"
                        sh "cd $WORKSPACE"
                        sh "ls"
                        sh "./build.sh --cpu --stable"
                    }
                }
            }
        }

        stage('test_dockers') {
            steps {
                echo "starting in $PWD"
                sh "cd $WORKSPACE"
                sh "ls"
                sh "./build_test_dockers.sh"
                sh "./run_docker_tests.sh"
                // sh "./publish_docker_images.sh" // do not publish by default
            }
        }
        // prerequisite for jenkins' docker plugin to login properly:
        // sudo apt install gnupg2 pass
        stage('publish_images') {
            steps {
                script {
                    docker.withRegistry('', registryCredential) {
                        sh "./publish_docker_images.sh"
                    }
                }
            }
        }
    }
    post { 
        always { 
            // step([$class: 'WsCleanup'])
            sh "chmod -R 777 ."
            cleanWs()
            deleteDir()
        }
        cleanup {
            deleteDir()
        }
    }
}
