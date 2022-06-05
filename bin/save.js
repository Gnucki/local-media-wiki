#! /usr/bin/env node

async function uploadBackup() {
  throw new Error('Backup upload is not implemented. Please do it manually.')
}

uploadBackup().then((fileId) => {
  console.info(`Created file : '${fileId}'`);
  process.exit(0);
}).catch((error) => {
  if (/not implemented/.test(error.message)) {
    console.warn(error.message);
    process.exit(0);
  }
  console.error(error);
  process.exit(1);
});
