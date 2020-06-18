properties([
  buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '3', daysToKeepStr: '', numToKeepStr: '20')),
  disableConcurrentBuilds(),
  parameters([
    booleanParam(name: 'CLEAN_WORKSPACE', defaultValue: true, description: 'Clean the workspace at the end of the run'),
    string(name: 'DOCKER_REGISTRY_DOWNLOAD_URL', defaultValue: 'nexus-docker-private-group.ossim.io', description: 'Docker registry pull url.'),
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
      image: "${DOCKER_REGISTRY_DOWNLOAD_URL}/docs-site-builder:latest",
      command: 'cat',
      ttyEnabled: true,
      envVars: [
        envVar(key: 'HOME', value: '/root')
      ]
    ),
    containerTemplate(
      image: "${DOCKER_REGISTRY_DOWNLOAD_URL}/alpine/helm:3.2.3",
      name: 'helm',
      command: 'cat',
      ttyEnabled: true
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

    stage("Checkout branch $BRANCH_NAME")
    {
      checkout(scm)
    }

    stage("Load Variables")
    {
      withCredentials([string(credentialsId: 'o2-artifact-project', variable: 'o2ArtifactProject')]) {
        step ([$class: "CopyArtifact",
          projectName: o2ArtifactProject,
          filter: "common-variables.groovy",
          flatten: true])
      }
      load "common-variables.groovy"
    }

    stage('Clone Repos') {
      container('docs-site-builder') {
        if (ADHOC_PROJECT_YAML == '') {
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
        sh """
          cd /home/jenkins/agent/
          docker build . -t ${DOCKER_REGISTRY_PRIVATE_UPLOAD_URL}/omar-docs:${BRANCH_NAME}
        """
      }
    }

    stage('Docker push'){
      container('docker') {
        withDockerRegistry(credentialsId: 'dockerCredentials', url: "https://${DOCKER_REGISTRY_PRIVATE_UPLOAD_URL}") {
          sh """
            docker push ${DOCKER_REGISTRY_PRIVATE_UPLOAD_URL}/omar-docs:${BRANCH_NAME}
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
      container('docs-site-builder') {
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
