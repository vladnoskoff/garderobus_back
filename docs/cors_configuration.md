# CORS configuration and common client errors

The API enables CORS through FastAPI's `CORSMiddleware` and the allowed origins come from `settings.CORS_ALLOWED_ORIGINS`. Because `allow_credentials=True` is set, browsers require an **exact match** of scheme, host, and port. Mismatches are the main reason users still see CORS failures after tightening the middleware.

## Typical problems
- **Scheme mismatch**: Only `https://` origins are allowed by default. If a client loads the admin panel over plain HTTP or from an IP with `http://`, the browser will block the request because that origin is not in the allow list.
- **Port mismatch**: Origins must include the port when it is not standard. A request from `https://example.com:8443` will fail unless that exact origin is in `CORS_ALLOWED_ORIGINS`.
- **Different hostnames**: Subdomains count as different origins. If the panel is opened from `admin.example.com` but only `example.com` is configured, preflight checks will be rejected.
- **File or custom schemes**: Mobile WebViews and desktop apps sometimes use `file://` or custom schemes. Those are not permitted by `allow_origins` and will be blocked; expose the app on an HTTPS origin and include it in the list instead.

## How to update the allow list
Set the environment variable `CORS_ALLOWED_ORIGINS` to a comma-separated list of full origins (including scheme and optional port), for example:

```
CORS_ALLOWED_ORIGINS=https://garderobus.noksovsteam.ru,https://app.garderobus.example,https://admin.garderobus.example:8443
```

After updating the environment and reloading the API process, the middleware will accept requests from the new origins while still rejecting others.
