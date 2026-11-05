/**
 * Strava OAuth token exchange / refresh.
 * Client never holds STRAVA_CLIENT_SECRET — only this function does.
 *
 * Deploy (Blaze required):
 *   firebase functions:secrets:set STRAVA_CLIENT_SECRET --project r-ally-2e048
 *   firebase deploy --only functions:stravaOAuth --project r-ally-2e048
 *
 * Env (non-secret):
 *   firebase functions:config:set strava.client_id="YOUR_ID"
 *   or set STRAVA_CLIENT_ID in the function params below via defineString.
 */
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret, defineString } = require("firebase-functions/params");

const stravaClientId = defineString("STRAVA_CLIENT_ID", { default: "" });
const stravaClientSecret = defineSecret("STRAVA_CLIENT_SECRET");

exports.stravaOAuth = onRequest(
  {
    region: "asia-south1",
    cors: true,
    secrets: [stravaClientSecret],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }

    const clientId = stravaClientId.value() || process.env.STRAVA_CLIENT_ID || "";
    const clientSecret = stravaClientSecret.value();
    if (!clientId || !clientSecret) {
      res.status(500).json({ error: "strava_not_configured" });
      return;
    }

    const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body || {};
    const grantType = body.grant_type;
    const payload = {
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: grantType,
    };

    if (grantType === "authorization_code") {
      if (!body.code) {
        res.status(400).json({ error: "missing_code" });
        return;
      }
      payload.code = body.code;
    } else if (grantType === "refresh_token") {
      if (!body.refresh_token) {
        res.status(400).json({ error: "missing_refresh_token" });
        return;
      }
      payload.refresh_token = body.refresh_token;
    } else {
      res.status(400).json({ error: "unsupported_grant_type" });
      return;
    }

    try {
      const upstream = await fetch("https://www.strava.com/oauth/token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const text = await upstream.text();
      res.status(upstream.status).type("application/json").send(text);
    } catch (err) {
      res.status(502).json({ error: "upstream_failed", detail: String(err && err.message ? err.message : err) });
    }
  }
);
