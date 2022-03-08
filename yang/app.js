const express = require("express"),
    http = require("http"),
    os = require("os"),
    app = express();

app.get("/", function (req, res) {
    const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    res.send(`Client ${clientIp} processed by ${os.hostname()}`);
});

http.createServer(app).listen(8080, "0.0.0.0", function () {
    console.log(`Server listening at ${this.address().address}:${this.address().port}`);
});
