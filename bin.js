#!/usr/bin/env node

const integration = require('./index')

async function start () {
  try {
    const msg = await integration.execute()
    console.log(msg)
  } catch (err) {
    console.error(err)
    process.exit(1)
  }
}

start()
