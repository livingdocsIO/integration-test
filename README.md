# Introduction

Here you can find scripts to support the setup for integration tests.
We want to assure that our changes in the upstream has no negative effect for our customers. Therefore we run integration tests from specific upstream branches against specific downstream branches. Because this connection between upstream and downstream has to be flexible, we have introduced this repository and the possibility to configure connections between up- and downstreams with a config in the upstream repository e.g. livingdocs-editor.

# Example Integration Setup

Create a new codeship build and add this lines to the 'setup' step in a build pipeline.

```bash
# Environment variable
export GH_ACCESS_TOKEN=...
# Script
export CURRENT_UPSTREAM_BRANCH=$CI_BRANCH
export CURRENT_UPSTREAM_REPO_NAME=$CI_REPO_NAME
export CURRENT_UPSTREAM_PATH=/home/rof/src/github.com/upfrontIO/livingdocs-editor
export CURRENT_DOWNSTREAM_PATH=/home/rof/src/github.com/downstream/livingdocs-editor
npm install git+https://git@github.com/upfrontIO/integration-test.git
. ./node_modules/integration-test/setup-downstream-integration.sh
```

As a next step add this lines to the 'configuration' step of the build pipeline.

```bash
export CURRENT_UPSTREAM_PROJECT=bluewin
li_clone_branch
li_log_scenario
# li_setup_editor and li_setup_server are available
li_setup_editor
npm install
npm test
```

As last step you have to add a file to your upstream repository with the name `livingdocs-integration.json` in the base folder. Here you have an example config.

```json
{
  "bluewin": {
    "default": {
      "downstream": {
        "repository": "upfrontIO/livingdocs-bluewin-editor",
        "integration-branch": "upstream-release-2017-11"
      }
    },
    "custom": [
      {
        "base-branch": "release-2017-10",
        "downstream": {
          "repository": "upfrontIO/livingdocs-bluewin-editor",
          "integration-branch": "upstream-release-2017-10"
        }
      }
    ]
  }
}
```

The handle from `CURRENT_UPSTREAM_PROJECT` has to match in this case with `bluewin`. Now you can define a default integration branch. If you want to define another integration branch for a specific `base-branch`, you can add custom integrations. `base-branch` means, when my upstream feature `my-feature` has `base-branch` as target.

I show you with some example based on the preceding config, how the integration works.

#### Exact Match Integration Test (Prio 1)

* Upstream Branch Name: `my-feature`
* Upstream Base Branch Name: `release-2017-11`
* Downstream Branch Name: `my-feature`

Integration Test: Downstream `my-feature` --> Upstream `my-feature`

#### Custom Integration Test (Prio 2)

* Upstream Branch Name: `my-feature`
* Upstream Base Branch Name: `release-2017-10`

Integration Test: Downstream `upstream-release-2017-10` --> Upstream `my-feature`

#### Default Integration Test (Prio 3)

* Upstream Branch Name: `my-feature`
* Upstream Base Branch Name: `master`

Integration Test: Downstream `upstream-release-2017-11` --> Upstream `my-feature`
