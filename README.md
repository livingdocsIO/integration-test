# Introduction

A drone plugin to clone downstream branches.

We want to ensure that our changes in the upstream has no negative effect for our customers, therefore we run integration tests from specific upstream branches against specific downstream branches.

Because this connection between upstream and downstream has to be flexible, we've introduced this tool to clone downstream repos based on a config in the upstream repository. This script doesn't do more than cloning repos, everything else should be done in a separate step.

# Example Integration Setup

Create a new droneci build and add those lines to the '.drone.yml' config to define a new step:
```yaml
pipeline:
  clone-downstreams:
    image: livingdocs/integration-test:3.0.1
    cwd: /drone/src
    secrets: [gh_token]
```

Add the repository to drone and configure the gh_token secret:
```bash
drone repo enable owner/repo
drone secret add --image livingdocs/integration-test --repository owner/repo --name GH_TOKEN --value GITHUBTOKEN
```

As last step you have to add a file with the name `livingdocs-integration.json` to your upstream repository (owner/repo).
Here's how such a file could look like:
```json
{
  "bluewin": {
    "repository": "bluewin/livingdocs-server",
    "defaultBranch": "upstream-release-2018-12",
    "customBranches": {
      "release-2018-11": "upstream-release-2018-11",
      "release-2018-10": "upstream-release-2018-10",
    }
  },
  "nzz": {
    "repository": "nzzdev/livingdocs-api",
    "defaultBranch": "upstream-release-2018-12",
    "customBranches": {
      "release-2018-11": "upstream-release-2018-11",
      "release-2018-10": "upstream-release-2018-10",
    }
  }
}
```

# Branch clone Behavior

#### Exact Match Integration Test (Prio 1)

* Upstream Branch Name: `my-feature`
* Upstream Base Branch Name: `release-2018-11`
* Downstream Branch Name: `my-feature`

Integration Test: Downstream `my-feature` --> Upstream `my-feature`

#### Custom Integration Test (Prio 2)

* Upstream Branch Name: `my-feature`
* Upstream Base Branch Name: `release-2018-11`

Integration Test: Downstream `upstream-release-2018-11` --> Upstream `my-feature`

#### Default Integration Test (Prio 3)

* Upstream Branch Name: `my-feature`
* Upstream Base Branch Name: `master`

Integration Test: Downstream `upstream-release-2018-11` --> Upstream `my-feature`

# Local Development

If you want to make local tests (e.g. for `my-test-branch` on `livingdocs-server`) you can run the script on your machine too:

```bash
GH_TOKEN=<your-gh-token> DRONE_REPO_OWNER=livingdocsIO DRONE_REPO_NAME=livingdocs-server DRONE_COMMIT_BRANCH=my-test-branch ./bin.js
```

If everything works fine
- it clones a nzz/bluewin folder in your current directory
- you get an output like below

```js
{
  bluewin: {
    name: 'bluewin',
    repo: 'livingdocsIO/livingdocs-bluewin-server',
    branch: 'master',
    cause: 'default'
  },
  nzz: {
    name: 'nzz',
    repo: 'nzzdev/livingdocs-api',
    branch: 'master',
    cause: 'default'
  }
}
```
