#!/usr/local/groovy-3.0.8/bin/groovy
def String repoUrl = '050124456784.dkr.ecr.eu-west-1.amazonaws.com'

pipeline{
    agent any
    options {
        timestamps()
        ansiColor('xterm')
        buildDiscarder(logRotator(numToKeepStr: '15'))
        disableConcurrentBuilds()
    }
    triggers {
        pollSCM('H/4 * * * 1-5');
        cron('H * * * 1-5')
    }
    environment {
        env = "[ 'dev', 'stage', 'prod']"
        repoUrl = "050124456784.dkr.ecr.eu-west-1.amazonaws.com"
        // SERVER_CREDENTAILS = credentials('server_credential')
    }
    // Install the golang version configured as "go" and add it to the path.
    // Ensure the desired Go version is installed
    // def root = tool type: 'go', name: 'Go 1.15'
  
    // parameters {
    //   string defaultValue: '${TAG}', description: '', name: 'BRANCH_TAG', trim: true
    // }
    
    stages{
        stage("CHECKOUT"){
            options {
                timeout(time: 5, unit: 'MINUTES') 
            }
            //echo "Execute the stage when the build is building a tag when the TAG_NAME variable exists"
            // when {
            //     buildingTag()
            // }
            // when {
            //     tag comparator: 'REGEXP', pattern: 'v*'
            // }
            // when {
            //     tag "v*"
            // }
            //echo 'Deploying only because this commit is tagged...

            steps{
                echo "========Executing Checkout stage========"
                // Get some code from a GitHub repository
                // git 'https://github.com/jglick/simple-maven-project-with-tests.git'
                // Refspec: '+refs/tags/*':'refs/remotes/origin/tags/*'
                // Branch Specifier: **/tags/**
                // git ([url: 'https://github.com/inecsoft/lineten.git'])
                // git show-ref --tags | tail -n1 |  awk -F "refs/tags/" '{print $2}'
                checkout([$class: 'GitSCM', 
                    // branches: [[name: "${params.BRANCH_TAG}"]], 
                    branches: [[name: 'refs/tags/*'.trim()]],
                    doGenerateSubmoduleConfigurations: false, 
                    extensions: [], 
                    gitTool: 'Default', 
                    submoduleCfg: [], 
                    userRemoteConfigs: [[url: 'https://github.com/inecsoft/lineten.git']]
                ])
                echo "value of ${params.TAG_NAME}"
                echo "value of env VAR: ${env.env}"
                sh 'printenv'
                sh 'pwd'
                sh '''
                  go version
                '''
            }
        }   
        
        stage("BUILD"){
            options {
                timeout(time: 5, unit: 'MINUTES') 
            }
            steps{
                echo "========Executing Build stage========"
                script {
                    try {
                        sh 'echo "Building packages for the infrastructure"'
                        sh '''
                            REGION="eu-west-1"
                            `aws ecr get-login --no-include-email --region ${REGION}`
                            docker build -t lineten .
                            docker tag lineten ${repoUrl}/${repo}:${env}-${tag}
                            docker push ${repoUrl}/${repo}:${env}-${tag}
                        '''
                    }
                    catch (ex) {
                        println (ex)
                    }
                }
            }
        }

        stage("TEST"){
            options {
                timeout(time: 5, unit: 'MINUTES') 
            }
            //Execute the stage when the build is building a tag when the TAG_NAME variable exists
            when {
                buildingTag()
            }
            // when {
            //     tag comparator: 'REGEXP', pattern: 'v*'
            // }

            steps {
                echo "========Executing Test stage========"
                echo "testing new version ${NEW_VERSION}"
            }

        }

        stage("DEPLOY"){
            options {
                timeout(time: 5, unit: 'MINUTES') 
            }
            input {
                message '"Are you sure you want to " + environments[i] + "?"'
                id '"Approve " + environments[i] + " Deployment (Y/N)"'
                ok 'Deploy'
            }
            steps{
                echo "========Executing Deploy stage========"
                script {
                    try {
                        sh 'echo "Deploying packages to the infrastructure"'
                        sh '''
                            result = sh label: "Record kubernetes deploy",returnStatus: true, script:"""
                                    kubectl -n ${namespace} set image deployment/${deployment} ${container}=${repoUrl}/${repo}:${env}-${tag} --record
                            """

                            //  logOutput ('kubectl update deployment returned ' + result)

                            result = sh label: "Wait for kubernetes deploy", returnStatus: true, script:"""
                                    kubectl rollout status --watch=true --timeout=600s -n ${namespace} deployment ${deployment}
                            """
                            //  logOutput ('kubectl wait returned ' + result)

                            if ( result != 0 ) {
                            
                            println ('kubectl update deployment failed - doing roll back')
                            result = sh label: "Rolling back kubernetes deployment", returnStatus: true, script:"""
                            kubectl rollout undo -n ${namespace} deployment ${deployment}"""
                            // logOutput ('kubectl rollback deployment returned ' + result + ' )
                            } else {
                            
                            // logOutput ('kubectl update deployment worked )
                            }
                        '''
                    }
                    catch (ex) {
                        println (ex)
                    }
                }
            }

        }
    }

}

// pipeline {
//     agent { docker { image 'golang' } }
//     stages {
//         stage('build') {
//             steps {
//                 sh 'go version'
//             }
//         }
//     }
// }



