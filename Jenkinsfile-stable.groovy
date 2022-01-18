pipeline {
    environment {
        registry = "dexai2/drake-pytorch"
        registryCredential = 'dockerhub'
    }
    agent any
    options {
        parallelsAlwaysFailFast()
    }
    stages {

        stage('build_drake_torch') {
            parallel {
                stage('build_cuda') {
                    steps {
                        echo "starting in $PWD"
                        sh "cd $WORKSPACE"
                        sh "ls"
                        sh "./build_image.sh --cuda --stable"
                    }
                }
                stage('build_cpu') {
                    steps {
                        echo "starting in $PWD"
                        sh "cd $WORKSPACE"
                        sh "ls"
                        sh "./build_image.sh --cpu --stable"
                    }
                }
            }
        }

        stage('build_drake_torch_ros') {
            parallel {
                stage('build_cuda') {
                    steps {
                        echo "starting in $PWD"
                        sh "cd $WORKSPACE"
                        sh "ls"
                        sh "./build_image.sh --cuda --stable --ros"
                    }
                }
                stage('build_cpu') {
                    steps {
                        echo "starting in $PWD"
                        sh "cd $WORKSPACE"
                        sh "ls"
                        sh "./build_image.sh --cpu --stable --ros"
                    }
                }
            }
        }

        stage('test_dockers') {
            steps {
                sh "./test_image.sh dexai2/drake-pytorch:cuda-stable-ros"
                // sh "./publish_docker_images.sh" // do not publish by default
            }
        }
        // prerequisite for jenkins' docker plugin to login properly:
        // sudo apt install gnupg2 pass
        stage('publish_images') {
            steps {
                script {
                    docker.withRegistry('', registryCredential) {
                        sh "./publish_image.sh --cuda --stable"
                        sh "./publish_image.sh --cuda --stable --ros"
                        sh "./publish_image.sh --cpu --stable"
                        sh "./publish_image.sh --cpu --stable --ros"
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
