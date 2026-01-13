const mongoose = require('mongoose');
const Account = require('/opt/open5gs-webui/server/models/account');

(async () => {
  await mongoose.connect(process.env.DB_URI);

  const username = process.env.WEBUI_ADMIN_USER || 'admin';
  const password = process.env.WEBUI_ADMIN_PASS || '1423';

  const exists = await Account.findOne({ username });
  if (!exists) {
    await new Promise((resolve, reject) => {
      Account.register(
        new Account({ username, name: 'Administrator', role: 'admin' }),
        password,
        (err) => (err ? reject(err) : resolve())
      );
    });
    console.log(`Created admin user: ${username}`);
  } else {
    console.log(`Admin user already exists: ${username}`);
  }

  await mongoose.disconnect();
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
