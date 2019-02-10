/* eslint-disable no-console */
const integration = require('./index')
integration.execute()
  .then((msg) => {
    console.log(JSON.parse(msg, null, 2))
  })
  .catch((err) => {
    console.error(err)
    process.exit(1)
  })
