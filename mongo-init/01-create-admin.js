db = db.getSiblingDB("open5gs");

db.accounts.insertOne({
  username: "admin",
  password: "1423",
  name: "Administrator",
  role: "admin",
  created_at: new Date()
});
