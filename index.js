const fs = require('fs')
const path = require('path')
const assert = require('assert')
const _ = require('lodash')
const execa = require('execa')

const username = 'x-oauth-basic'
const token = process.env.GH_TOKEN
const OWNER = process.env.DRONE_REPO_OWNER
const REPO = process.env.DRONE_REPO_NAME
const REPO_BASE = process.env.DRONE_REPO_BRANCH || 'master'
const PULL_REQUEST_NR = process.env.DRONE_PULL_REQUEST
const CURRENT_BRANCH = process.env.DRONE_COMMIT_BRANCH
const DEPTH = Math.max(process.env.PLUGIN_DEPTH, 1) || 1
const DOWNSTREAMS = (process.env.PLUGIN_DOWNSTREAMS || '').split(/(, )/).filter(Boolean)
const INTEGRATION_FILE = process.env.PLUGIN_FILE || 'livingdocs-integration.json' // eslint-disable-line max-len
const REMOTE_FILE = ['true', true].includes(process.env.PLUGIN_REMOTE)
const LOCAL_INTEGRATION_FILE_PATH = !REMOTE_FILE && path.resolve(INTEGRATION_FILE)
const CWD = process.env.PLUGIN_CWD || process.cwd()

assert(token, 'The variable GH_TOKEN is required.')
assert(OWNER, 'The variable DRONE_REPO_OWNER is required.')
assert(REPO, 'The variable DRONE_REPO_NAME is required.')
assert(CURRENT_BRANCH, 'The variable DRONE_COMMIT_BRANCH is required.')

const octokit = require('@octokit/rest')()
octokit.authenticate({type: 'oauth', token})

fs.writeFileSync(`${process.env.HOME}/.netrc`, [
  `machine github.com`,
  `login ${username}`,
  `password ${token}`
].join('\n'))

async function getIntegrationFile () {
  let fileContent
  if (LOCAL_INTEGRATION_FILE_PATH) {
    fileContent = fs.readFileSync(LOCAL_INTEGRATION_FILE_PATH, 'utf8')
  } else {
    const resp = await octokit.repos.getContent({
      owner: OWNER,
      repo: REPO,
      ref: REPO_BASE,
      path: INTEGRATION_FILE
    })

    fileContent = Buffer.from(resp.data.content, 'base64').toString()
  }

  return normalizeLegacyIntegrationFile(JSON.parse(fileContent))
}

function normalizeLegacyIntegrationFile (json) {
  const normalized = {}
  for (const name in json) {
    const orig = json[name]
    if (orig.repository) {
      normalized[name] = orig
      continue
    }
    normalized[name] = {
      repository: orig.default.downstream['repository'],
      defaultBranch: orig.default.downstream['integration-branch'],
      customBranches: _.mapValues(_.keyBy(orig.custom, 'base-branch'), (c) => {
        return c.downstream['integration-branch']
      })
    }
  }
  return normalized
}

async function extractTargetBranches (integrationFile) {
  const downstreams = {}
  const prBaseBranch = PULL_REQUEST_NR && await getPRBase()
  const isGreenkeeper = /^greenkeeper\//.test(CURRENT_BRANCH)

  for (const name in integrationFile) {
    // Only include whitelisted downstreams
    if (DOWNSTREAMS.length && !DOWNSTREAMS.includes(name)) continue

    const downstreamConfig = integrationFile[name]
    const repo = downstreamConfig.repository
    const downstream = {name, repo}
    downstreams[name] = downstream

    if (CURRENT_BRANCH === REPO_BASE || isGreenkeeper) {
      const defaultBranch = isGreenkeeper ? 'greenkeeper' : 'base'
      const {branch, cause} = await fallbackDefault(defaultBranch, downstreamConfig)
      downstream.branch = branch
      downstream.cause = cause
      continue
    }

    if (await hasBranch(downstreamConfig.repository, CURRENT_BRANCH)) {
      downstream.branch = CURRENT_BRANCH
      downstream.cause = 'current'
      continue
    }

    const customBranch = (downstreamConfig.customBranches || {})[prBaseBranch]
    if (customBranch && await hasBranch(downstreamConfig.repository, customBranch)) {
      downstream.branch = customBranch
      downstream.cause = 'custom'
      continue
    }

    const {branch, cause} = await fallbackDefault('default', downstreamConfig)
    downstream.branch = branch
    downstream.cause = cause
  }
  return downstreams
}

async function getPRBase () {
  const resp = await octokit.pullRequests.get({owner: OWNER, repo: REPO, number: PULL_REQUEST_NR})
  return resp.data.base.ref
}

async function hasBranch (repository, branch) {
  if (!branch) return false

  const [owner, repo] = repository.split('/')
  return octokit.repos.getBranch({owner, repo, branch})
    .then((result) => true)
    .catch((result) => {
      if (result.code === 404) return false
      throw result
    })
}

async function fallbackDefault (cause, downstreamConfig) {
  const hasDefault = await hasBranch(downstreamConfig.repository, downstreamConfig.defaultBranch)
  return {
    repo: downstreamConfig.repository,
    branch: hasDefault ? downstreamConfig.defaultBranch : 'master',
    cause
  }
}

async function cloneAll (targets) {
  await Promise.all(Object.values(targets).map(async (target) => {
    const dir = path.join(CWD, target.name)
    await execa('rm', ['-Rf', `${dir}`])
    await execa('mkdir', ['-p', `${dir}`])
    await execa(`git`, [
      `clone`,
      `--branch`, target.branch,
      `--depth`, DEPTH,
      `https://github.com/${target.repo}.git`,
      `${dir}`
    ])
  }))
  return targets
}

async function execute () {
  const integrationFile = await getIntegrationFile()
  const targets = await extractTargetBranches(integrationFile)
  return cloneAll(targets)
}

module.exports = {execute, getIntegrationFile}
