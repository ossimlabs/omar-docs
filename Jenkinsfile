properties([
  buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '3', daysToKeepStr: '', numToKeepStr: '20')),
  disableConcurrentBuilds(),
  parameters([
    string(name: 'IMAGE_TAG', defaultValue: 'latest', description: 'Docker image tag used when publishing'),
    string(name: 'IMAGE_NAME', defaultValue: 'omar-docs-2', description: 'Docker image name used when publishing'),
    string(name: 'DOCKER_REGISTRY', defaultValue: 'nexus-docker-private-group.ossim.io', description: 'The repository to find the necessary doc builder image. Also the place to publish the restultant docs-service image.'),
    text(name: 'ADHOC_PROJECT_YAML', defaultValue: '', description: 'Override the project vars used to generate documentation')
  ])
])

podTemplate(
  containers: [
    containerTemplate(
      name: 'docker',
      image: 'docker:latest',
      ttyEnabled: true,
      command: 'cat',
      privileged: true
    ),
    containerTemplate(
        name: 'docs-site-builder',
        image: "${DOCKER_REGISTRY}/docs-site-builder:latest",
        command: 'cat',
        ttyEnabled: true,
        envVars: [
          envVar(key: 'HOME', value: '/root')
        ]
    )
  ],
  volumes: [
    hostPathVolume(
      hostPath: '/var/run/docker.sock',
      mountPath: '/var/run/docker.sock'
    )
  ]
) {
  node(POD_LABEL) {
    stage('Clone Repos') {
        container('docs-site-builder') {
          if (ADHOC_PROJECT_YAML == '') {
            checkout(scm)
            sh 'cp ./omar-vars.yml /docs-site-builder/project_vars.yml'

          } else {
            sh 'echo "${ADHOC_PROJECT_YAML}" > /docs-site-builder/project_vars.yml'
          }
          sh '''
            cd /docs-site-builder
            python3 tasks/clone_repos.py -c project_vars.yml
          '''
        }
    }

    stage('Build site') {
      container('docs-site-builder') {
      sh '''
        cd /docs-site-builder
        python3 tasks/generate.py -c project_vars.yml
        cp -r site/ /home/jenkins/agent/site/
        cp docker/docs-service/Dockerfile /home/jenkins/agent/Dockerfile
      '''
      }
    }

      stage('Docker build') {
        container('docker') {
          withDockerRegistry(credentialsId: 'dockerCredentials', url: "https://${DOCKER_REGISTRY_DOWNLOAD_URL}") {
            sh """
              docker build . -t ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
            """
           }
         }
       }

      stage('Docker push'){
        container('docker') {
          withDockerRegistry(credentialsId: 'dockerCredentials', url: "https://${DOCKER_REGISTRY_PUBLIC_UPLOAD_URL}") {
            sh """
              docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
            """
          }
        }
      }

       stage('Package chart'){
         container('helm') {
           sh """
               mkdir packaged-chart
               helm package -d packaged-chart chart
             """
         }
       }
       stage('Upload chart'){
         container('builder') {
           withCredentials([usernameColonPassword(credentialsId: 'helmCredentials', variable: 'HELM_CREDENTIALS')]) {
             sh "curl -u ${HELM_CREDENTIALS} ${HELM_UPLOAD_URL} --upload-file packaged-chart/*.tgz -v"
           }
         }
       }

       stage("Clean Workspace"){
         if ("${CLEAN_WORKSPACE}" == "true")
           step([$class: 'WsCleanup'])
       }
    }
  }
}