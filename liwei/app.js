const express = require("express"),
    session = require("express-session"),
    http = require("http"),
    app = express(),
    MemcachedStore = require("connect-memcached")(session);
app.use(
    session({
        secret: "secret",
        cookie: {domain: ".testdomain.ovh", maxAge: 3600 * 1000},
        key: "test",
        proxy: "true",
        resave: false,
        saveUninitialized: false,
        store: new MemcachedStore({
            hosts: process.env.MEMCACHED.split(",")
        })
    })
);
app.get("/", function (req, res) {
    if (!req.session.views) {
        req.session.views = 0;
    }
    req.session.views++;
    res.send(`Viewed ${req.session.views} times`);
});

http.createServer(app).listen(80, "0.0.0.0", function () {
    console.log(`Server listening at ${this.address().address}:${this.address().port}, memcached: ${process.env.MEMCACHED}`);
});
