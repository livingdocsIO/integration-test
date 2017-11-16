#!/bin/bash
#
# MANDATORY ENVIRONMENT VARIABLES
# -------------------------------
# CURRENT_UPSTREAM_BRANCH = The branch where the upstream commit happened e.g. my-upstream-branch
# CURRENT_UPSTREAM_REPO_NAME = Repository Name e.g. upfrontIO/livingdocs-editor
# CURRENT_UPSTREAM_PROJECT = Project name for the integration lookup in livingdocs-integration.json e.g. bluewin
# GH_ACCESS_TOKEN = Token for accessing the github API from the upstream project e.g. upfrontIO/livingdocs-editor
# REPO_SOURCE_PATH = File path to the repository in the build environment
function setup_commands () {
  # ------------------------------
  DESTINATION="${DESTINATION:-$PWD}"

  function li_clone_branch () {
    if [ -z $CURRENT_UPSTREAM_BRANCH ]; then
        >&2 echo 'The environment variable "$CURRENT_UPSTREAM_BRANCH" is required e.g. CURRENT_UPSTREAM_BRANCH=my-feature'
        return 1
    fi

    if [ -z $CURRENT_UPSTREAM_REPO_NAME ]; then
        >&2 echo 'The environment variable "$CURRENT_UPSTREAM_REPO_NAME" is required e.g. CURRENT_UPSTREAM_REPO_NAME=upfrontIO/livingdocs-editor'
        return 1
    fi

    if [ -z $CURRENT_UPSTREAM_PROJECT ]; then
        >&2 echo 'The environment variable "$CURRENT_UPSTREAM_PROJECT" is required e.g. CURRENT_UPSTREAM_PROJECT=bluewin'
        return 1
    fi

    if [ -z $GH_ACCESS_TOKEN ]; then
        >&2 echo 'The environment variable "$GH_ACCESS_TOKEN" is required'
        return 1
    fi

    if [ -z $REPO_SOURCE_PATH ]; then
        >&2 echo 'The environment variable "$REPO_SOURCE_PATH" is required e.g. REPO_SOURCE_PATH=/home/rof/src/github.com/upfrontIO/livingdocs-editor'
        return 1
    fi

    INTEGRATION_CONFIG=$REPO_SOURCE_PATH/livingdocs-integration.json

    if [ ! -f $INTEGRATION_CONFIG ]; then
      >&2 echo "The file '$INTEGRATION_CONFIG' does not exist and is needed to run the integration tests."
      return 1
    fi


    # Read DEFAULT SETTINGS out of integration config
    # -----------------------------------------------
    # e.g. upfrontIO/livingdocs-bluewin-editor
    DEFAULT_REPO_NAME=`cat $INTEGRATION_CONFIG | jq --arg proj "$CURRENT_UPSTREAM_PROJECT" '.[$proj].default.downstream.repository' | tr -d '"'`
    >&2 echo ""
    >&2 echo "---------- DEBUG LOG --------------"
    >&2 echo "DEFAULT_REPO_NAME: $DEFAULT_REPO_NAME"

    # e.g. upstream-release-2017-11
    DEFAULT_INTEGRATION_BRANCH=`cat $INTEGRATION_CONFIG | jq --arg proj "$CURRENT_UPSTREAM_PROJECT" '.[$proj].default.downstream["integration-branch"]' | tr -d '"'`
    >&2 echo "DEFAULT_INTEGRATION_BRANCH: $DEFAULT_INTEGRATION_BRANCH"
    # -----------------------------------------------


    # CURRENT_UPSTREAM_BRANCH points to CURRENT_UPSTREAM_BASE_BRANCH in a PR
    >&2 echo "CURRENT_UPSTREAM_BRANCH: $CURRENT_UPSTREAM_BRANCH"
    PR_URL="https://api.github.com/repos/$CURRENT_UPSTREAM_REPO_NAME/pulls"
    CURRENT_UPSTREAM_BASE_BRANCH=`curl -H "Authorization: token $GH_ACCESS_TOKEN" -Ss $PR_URL | jq --arg current_upstream_branch "$CURRENT_UPSTREAM_BRANCH" '.[] | select(.head.ref==$current_upstream_branch) | .base.ref' | tr -d '"'`
    >&2 echo "CURRENT_UPSTREAM_BASE_BRANCH: $CURRENT_UPSTREAM_BASE_BRANCH"


    # Read CUSTOM SETTINGS out of integration config
    # -----------------------------------------------
    # e.g. upfrontIO/livingdocs-bluewin-editor
    CUSTOM_REPO_BASE=`cat $INTEGRATION_CONFIG | jq --arg upstream_base_branch_name "$CURRENT_UPSTREAM_BASE_BRANCH" --arg proj "$CURRENT_UPSTREAM_PROJECT" '.[$proj].custom[] | select(.["base-branch"]==$upstream_base_branch_name) | .downstream.repository' | tr -d '"'`
    CUSTOM_REPO=`cat $INTEGRATION_CONFIG | jq --arg upstream_base_branch_name "$CURRENT_UPSTREAM_BRANCH" --arg proj "$CURRENT_UPSTREAM_PROJECT" '.[$proj].custom[] | select(.["base-branch"]==$upstream_base_branch_name) | .downstream.repository' | tr -d '"'`
    CUSTOM_REPO_NAME=${CUSTOM_REPO:-$CUSTOM_REPO_BASE}
    >&2 echo "CUSTOM_REPO_NAME: $CUSTOM_REPO_NAME"
    # e.g. upstream-release-2017-01
    CUSTOM_INTEGRATION=`cat $INTEGRATION_CONFIG | jq --arg upstream_base_branch_name "$CURRENT_UPSTREAM_BRANCH" --arg proj "$CURRENT_UPSTREAM_PROJECT" '.[$proj].custom[] | select(.["base-branch"]==$upstream_base_branch_name) | .downstream["integration-branch"]' | tr -d '"'`
    CUSTOM_INTEGRATION_BASE=`cat $INTEGRATION_CONFIG | jq --arg upstream_base_branch_name "$CURRENT_UPSTREAM_BASE_BRANCH" --arg proj "$CURRENT_UPSTREAM_PROJECT" '.[$proj].custom[] | select(.["base-branch"]==$upstream_base_branch_name) | .downstream["integration-branch"]' | tr -d '"'`
    CUSTOM_INTEGRATION_BRANCH_NAME=${CUSTOM_INTEGRATION:-$CUSTOM_INTEGRATION_BASE}
    >&2 echo "CUSTOM_INTEGRATION_BRANCH_NAME: $CUSTOM_INTEGRATION_BRANCH_NAME"
    >&2 echo "---------- DEBUG LOG --------------"
    >&2 echo ""
    # -----------------------------------------------


    # clone the right branch
    DOWNSTREAM_REPO_NAME=${CUSTOM_REPO_NAME:-$DEFAULT_REPO_NAME}
    DOWNSTREAM_REPO_URL="git@github.com:$DOWNSTREAM_REPO_NAME.git"
    DOWNSTREAM_REPO_DESTINATION=$DESTINATION/$DEFAULT_REPO_NAME
    mkdir -p $DOWNSTREAM_REPO_DESTINATION

    if [ $CURRENT_UPSTREAM_BRANCH == "master" ]; then
      >&2 echo "The CURRENT_UPSTREAM_BRANCH is 'master'";
      git clone --branch $DEFAULT_INTEGRATION_BRANCH --depth 50 $DOWNSTREAM_REPO_URL $DOWNSTREAM_REPO_DESTINATION || \
      git clone --branch master --depth 50 $DOWNSTREAM_REPO_URL $DOWNSTREAM_REPO_DESTINATION || \
      return 1
    else
      >&2 echo "The CURRENT_UPSTREAM_BRANCH is not 'master'" && \
      git clone --branch $CURRENT_UPSTREAM_BRANCH --depth 50 $DOWNSTREAM_REPO_URL $DOWNSTREAM_REPO_DESTINATION || \
      git clone --branch $CUSTOM_INTEGRATION_BRANCH_NAME --depth 50 $DOWNSTREAM_REPO_URL $DOWNSTREAM_REPO_DESTINATION || \
      git clone --branch $DEFAULT_INTEGRATION_BRANCH --depth 50 $DOWNSTREAM_REPO_URL $DOWNSTREAM_REPO_DESTINATION || \
      git clone --branch master --depth 50 $DOWNSTREAM_REPO_URL $DOWNSTREAM_REPO_DESTINATION || \
      return 1
    fi

    cd $DOWNSTREAM_REPO_DESTINATION

    # Log the test scenario
    >&2 echo ""
    >&2 echo "---------- TEST SCENARIO --------------"
    DOWNSTREAM_BRANCH=`echo $(git rev-parse --abbrev-ref HEAD | grep -v ^HEAD$ || git rev-parse HEAD)`
    >&2 echo "Current Directory: $DOWNSTREAM_REPO_DESTINATION"
    >&2 echo "Test downstream '$DOWNSTREAM_REPO_NAME/$DOWNSTREAM_BRANCH' against upstream '$CURRENT_UPSTREAM_BRANCH'"
    >&2 echo "---------- TEST SCENARIO --------------"
    >&2 echo ""
  }

  function li_setup_server () {
    . ~/.nvm/nvm.sh
    nvm install
    cp -R ../../$CURRENT_UPSTREAM_REPO_NAME ./_livingdocs-server
    sed -i 's/"@livingdocs\/server": ".*"/"\@livingdocs\/server": "file:.\/_livingdocs-server"/' package.json
  }

  function li_setup_editor () {
    . ~/.nvm/nvm.sh
    nvm install
    echo $CURRENT_UPSTREAM_REPO_NAME
    ls ../../$CURRENT_UPSTREAM_REPO_NAME
    pwd
    cp -R ../../$CURRENT_UPSTREAM_REPO_NAME ./_livingdocs-editor
    sed -i 's/"@livingdocs\/editor": ".*"/"\@livingdocs\/editor": "file:.\/_livingdocs-editor"/' package.json
  }
}

setup_commands
