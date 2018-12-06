const assert = require('assert')
process.env.PLUGIN_LOCAL_INTEGRATION_FILE = true
process.env.GH_TOKEN = 'foo'
process.env.DRONE_REPO_OWNER = 'foo'
process.env.DRONE_REPO_NAME = 'foo'
process.env.DRONE_COMMIT_BRANCH = 'foo'

const integration = require('./index')

assert.equal(typeof integration.execute, 'function')
assert.equal(typeof integration.getIntegrationFile, 'function')

integration.getIntegrationFile()
  .then((integrationFile) => {
    assert.equal(integrationFile.bluewin.repository, 'livingdocsIO/livingdocs-bluewin-server')
    assert.equal(integrationFile.bluewin.defaultBranch, 'upstream-release-2018-08')
  })
