import { createServer } from "node:http";
createServer((_req, res) => res.end(process.env.UPSTREAM_ROLE)).listen(Number(process.env.PORT ?? 7681), "0.0.0.0");
