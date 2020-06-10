pipeline {
    environment {
        registry = "dexai2/drake-torch"
        registryCredential = 'dockerhub'
    }
    agent any
    stages {
        
        // stage('clone_drake-torch') {
        //     steps {
        //         echo "starting in $PWD"
        //         git branch: 'master', url: 'https://github.com/DexaiRobotics/drake-torch.git'
        //         echo "moved to $PWD"
        //     }
        // }

        stage('build_deploy_images') {
            parallel {
                stage('build_cuda') {
                    steps {
                        echo "starting in $PWD"
                        sh "cd $WORKSPACE"
                        sh "ls"
                        sh "./build.sh --cuda"
                    }
                }
                stage('build_cpu') {
                    steps {
                        echo "starting in $PWD"
                        sh "cd $WORKSPACE"
                        sh "ls"
                        sh "./build.sh --cpu"
                    }
                }
            }
        }

        // stage('build_cuda') {
        //     steps {
        //         echo "starting in $PWD"
        //         sh "cd $WORKSPACE"
        //         sh "ls"
        //         sh "./build.sh --cuda"
        //     }
        // }

        // stage('build_cpu') {
        //     steps {
        //         echo "starting in $PWD"
        //         sh "cd $WORKSPACE"
        //         sh "ls"
        //         sh "./build.sh --cpu"
        //     }
        // }

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

        stage('dig_compability_tests') {
            parallel {
                stage('dig_cuda') {
                    agent {
                        docker {
                            image 'drake-torch:cuda'// 'dexai2/drake-torch:cuda_20200427'
                            args '-u root'
                            // label 'dexai_cuda' // to be defined earlier
                            // args  '-v /tmp:/tmp'
                        }
                    }
                    options { retry(0) }
                    steps {
                        
                        // sh 'find -L . -type l | xargs rm'
                        sh 'ls'
                        sh 'rm -rf src'
                        // sh 'find . -user root -name \'*\' | xargs chmod ugo+rw'
                        // deleteDir()
                        echo "starting in $PWD"
                        // git branch: 'dmsj.nightly.dig_initial', credentialsId: 'b33c5d11-c5ae-4b37-9f8e-9c67850e8af4', url: 'git@github.com:DexaiRobotics/fullstack.git'
                        
                        checkout([$class: 'GitSCM',
                            branches: [[name: 'dyt.ci']],
                            doGenerateSubmoduleConfigurations: false,
                            extensions: [[$class: 'SubmoduleOption',
                                            disableSubmodules: false,
                                            parentCredentials: true,
                                            recursiveSubmodules: true,
                                            reference: '',
                                            trackingSubmodules: true,
                                            depth: 1],
                                        [$class: 'WipeWorkspace'],
                                        [$class: 'CleanBeforeCheckout',
                                            deleteUntrackedNestedRepositories: true],
                                        [$class: 'CleanCheckout',
                                            deleteUntrackedNestedRepositories: true],
                                        [$class: 'GitLFSPull']], 
                            submoduleCfg: [], 
                            userRemoteConfigs: [[url: 'git@github.com:DexaiRobotics/fullstack.git', credentialsId: 'b33c5d11-c5ae-4b37-9f8e-9c67850e8af4']]])
                        
                        sh "echo 'moved to $PWD'"
                        sh "cd $WORKSPACE"
                        echo "ideally in $WORKSPACE which is the same as $PWD"
                        sh "ls"
                        sh "cd / && ls"
                        sh "cd /home && ls"
                        sh "cd /opt && ls"
                        sh "whoami"
                        sh "cd /root && ls"
                        sh "cd / && ln -s $WORKSPACE/src /src"
                        // sh "cd /src/traj_lib2 && git lfs install && git lfs update && git lfs pull && git lfs env"
                        sh "cd /src && ls && ./build_dexai_stack.sh --dig"
                        // sh "./bootstrap.sh --cuda"
                        // sh 'find . -user root -name \'*\' | xargs chmod ugo+rw'
                        sh 'ls'
                        sh 'rm -rf src'
                    }
                }
                stage('dig_cpu') {
                    agent {
                        docker {
                            image 'drake-torch:cpu'// 'dexai2/drake-torch:cuda_20200427'
                            args '-u root'
                            // label 'dexai_cuda' // to be defined earlier
                            // args  '-v /tmp:/tmp'
                        }
                    }
                    options { retry(0) }
                    steps {
                        // sh 'find . -user root -name \'*\' | xargs chmod ugo+rw'
                        sh 'ls'
                        sh 'rm -rf src'
                        echo "starting in $PWD"
                        // git branch: 'dmsj.nightly.dig_initial', credentialsId: 'b33c5d11-c5ae-4b37-9f8e-9c67850e8af4', url: 'git@github.com:DexaiRobotics/fullstack.git'
                        
                        checkout([$class: 'GitSCM',
                            branches: [[name: 'dyt.ci']],
                            doGenerateSubmoduleConfigurations: false,
                            extensions: [[$class: 'SubmoduleOption',
                                            disableSubmodules: false,
                                            parentCredentials: true,
                                            recursiveSubmodules: true,
                                            reference: '',
                                            trackingSubmodules: true,
                                            depth: 1],
                                        [$class: 'WipeWorkspace'],
                                        [$class: 'CleanBeforeCheckout',
                                            deleteUntrackedNestedRepositories: true],
                                        [$class: 'CleanCheckout',
                                            deleteUntrackedNestedRepositories: true],
                                        [$class: 'GitLFSPull']], 
                            submoduleCfg: [], 
                            userRemoteConfigs: [[url: 'git@github.com:DexaiRobotics/fullstack.git', credentialsId: 'b33c5d11-c5ae-4b37-9f8e-9c67850e8af4']]])
                        
                        sh "echo 'moved to $PWD'"
                        sh "cd $WORKSPACE"
                        echo "ideally in $WORKSPACE which is the same as $PWD"
                        sh "ls"
                        sh "cd / && ls"
                        sh "cd /home && ls"
                        sh "cd /opt && ls"
                        sh "whoami"
                        sh "cd /root && ls"
                        sh "cd / && ln -s $WORKSPACE/src /src"
                        // sh "cd /src/traj_lib2 && git lfs install && git lfs update && git lfs pull && git lfs env"
                        sh "cd /src && ls && ./build_dexai_stack.sh --dig"
                        // sh "./bootstrap.sh --cuda"
                        // sh 'find . -user root -name \'*\' | xargs chmod ugo+rw'
                        sh 'ls'
                        sh 'rm -rf src'
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
