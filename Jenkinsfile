properties([
  buildDiscarder(logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '3', daysToKeepStr: '', numToKeepStr: '20')),
  disableConcurrentBuilds(),
  parameters([
    booleanParam(name: 'CLEAN_WORKSPACE', defaultValue: true, description: 'Clean the workspace at the end of the run'),
    string(name: 'DOCKER_REGISTRY_DOWNLOAD_URL', defaultValue: 'nexus-docker-private-group.ossim.io', description: 'Docker registry pull url.'),
    string(name: 'BUILDER_VERSION', defaultValue: '2.2.1', description: 'Version of the docs-site-builder image to use.'),
    string(name: 'VERSION', defaultValue: '', description: 'The version tag with which to build the docker image. Defaults to branch name, except on master.'),
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
      image: "${DOCKER_REGISTRY_DOWNLOAD_URL}/docs-site-builder:${BUILDER_VERSION}",
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

    container('docs-site-builder') {
      stage("Copy files") {
        sh """
        cp -r /docs-site-builder/src .
      """
      }
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
        if (ADHOC_PROJECT_YAML != '') {
          sh 'echo "${ADHOC_PROJECT_YAML}" > /docs-site-builder/omar-vars.yml'
        }
        sh """
          python3 src/tasks/clone_repos.py -c omar-vars.yml
        """
      }
    }

    stage('Build site') {
      container('docs-site-builder') {
        sh '''
          python3 src/tasks/generate.py -c omar-vars.yml
        '''
      }
    }

    stage('Docker build') {
      container('docker') {
        if (BRANCH_NAME == "master") {
          if (VERSION == '') {
            print "Please specify a version when building on master."
            exit 1
          } else {
            TAG = VERSION
          }
        } else {
          TAG = BRANCH_NAME
        }

        sh """
          docker build . -t ${DOCKER_REGISTRY_PRIVATE_UPLOAD_URL}/omar-docs-app:${TAG}
        """
      }
    }

    stage('Docker push'){
      container('docker') {
        withDockerRegistry(credentialsId: 'dockerCredentials', url: "https://${DOCKER_REGISTRY_PRIVATE_UPLOAD_URL}") {
          sh """
            docker push ${DOCKER_REGISTRY_PRIVATE_UPLOAD_URL}/omar-docs-app:${TAG}
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
