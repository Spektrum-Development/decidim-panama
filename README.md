# decidim_panama

Free Open-Source participatory democracy, citizen participation and open government for cities and organizations

This is the open-source repository for decidim_panama, based on [Decidim](https://github.com/decidim/decidim).

## Production job queue

Solid Queue uses a separate PostgreSQL database. Set `DATABASE_URL` for the
application and `QUEUE_DATABASE_URL` for a different, dedicated queue database.
Run `bin/rails db:prepare` before starting workers to create or migrate the
databases and load the queue schema.

The Docker entrypoint runs `db:prepare` and `data:migrate` before starting its
command. For multi-instance deployments, run these tasks once during deployment
and set `SKIP_MIGRATIONS=1` on the instances. Run `bin/jobs` as a separate
worker process with the same database configuration. Alternatively, set
`SOLID_QUEUE_IN_PUMA=true` to run the supervisor inside Puma instead of running
a separate worker. `QUEUE_ADAPTER` selects the Active Job adapter and defaults
to `solid_queue`.

### Docker examples

Build the image and use an existing Docker network named `decidim` that can
reach PostgreSQL. Create a private environment file outside the repository
(for example, `../decidim-production.env`) containing `DATABASE_URL`,
`QUEUE_DATABASE_URL`, `SECRET_KEY_BASE`, and any other production settings.
Database hosts in the URLs must be reachable from the containers; `localhost`
inside a container refers to that container. Set `QUEUE_ADAPTER=solid_queue`.

Prepare the databases once before starting either container:

```sh
docker build -t decidim-panama .
docker run --rm --network decidim --env-file ../decidim-production.env \
  -e SKIP_MIGRATIONS= decidim-panama true
```

The entrypoint runs both database preparation and data migrations. On a new
primary database, preparation also runs Decidim seeds, which currently fail if
no organization exists.

Run Puma and a separate jobs container:

```sh
docker run -d --name decidim-web --network decidim \
  --env-file ../decidim-production.env -e SKIP_MIGRATIONS=1 \
  -e SOLID_QUEUE_IN_PUMA=false -p 3000:3000 decidim-panama
docker run -d --name decidim-jobs --network decidim --no-healthcheck \
  --env-file ../decidim-production.env -e SKIP_MIGRATIONS=1 decidim-panama bin/jobs
```

The web container explicitly disables the supervisor to override any setting
in the environment file; `false` is already the default.

Alternatively, run one Puma container with the queue supervisor enabled
instead of the separate jobs container:

```sh
docker run -d --name decidim-web --network decidim \
  --env-file ../decidim-production.env -e SKIP_MIGRATIONS=1 \
  -e SOLID_QUEUE_IN_PUMA=true -p 3000:3000 decidim-panama
```

When using local file storage, mount the same persistent storage at
`/app/storage` in both containers and make it writable by UID 1000.

## Setting up the application

You will need to do some steps before having the app working properly once you have deployed it:

1. Create a System Admin user: `bin/rails decidim_system:create_admin`
1. Visit `<your app url>/system` and log in with your system admin credentials
1. Create a new organization. Check the locales you want to use for that organization, and select a default locale.
1. Set the correct default host for the organization, otherwise the app will not work properly. Note that you need to include any subdomain you might be using.
1. Fill the rest of the form and submit it.

You are good to go!

## Panamá Conecta SSO

The Panamá Conecta OmniAuth provider is enabled when `CONECTA_CLIENT_ID`
and `CONECTA_CLIENT_TOKEN` are set. If `CONECTA_CLIENT_DOMAIN` is unset, the
current Decidim request host is used as the client domain. The client token is
sent to Panamá Conecta's `service-sso` endpoint and as the login `accessToken`.

| Environment variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `CONECTA_CLIENT_ID` | Yes | — | Registered client ID required by the provider configuration. |
| `CONECTA_CLIENT_TOKEN` | Yes | — | Registered `clientSecretToken`; sent in the `service-sso` JSON body and login URL. |
| `CONECTA_CLIENT_DOMAIN` | No | Current request host | Optional registered Decidim domain; used as OmniAuth's public host and the API request's `Referer`. |
| `CONECTA_SITE` | No | `https://qapanamaconecta.aig.gob.pa` | Panamá Conecta login site; also sent as the `Origin` header to its API. |
| `CONECTA_API_SITE` | No | `https://apiqapanamaconecta.aig.gob.pa:8443` | Base URL for the `service-sso` and user-info API requests. |
| `CONECTA_APP_TYPE` | No | `web` | Application type included in the login URL, such as `web` or `desktop`. |

Register the callback URL `<clientDomain>/users/auth/panama_conecta/callback` with Panamá Conecta.
The sign-in button uses OmniAuth's normal request route for `panama_conecta`.

Example environment configuration (keep real credentials in a private
environment file or secret manager, not in source control):

```sh
CONECTA_CLIENT_ID=your-client-id
CONECTA_CLIENT_TOKEN=your-client-secret-token
CONECTA_CLIENT_DOMAIN=https://your-decidim-domain.example
# Panamá Conecta environment URLs:
CONECTA_SITE=https://the-panama-conecta-domain
CONECTA_API_SITE=https://the-panama-conect-api-domain
# CONECTA_APP_TYPE=web
```

The normal OmniAuth request route starts the flow. The strategy posts
`{ "clientToken": "..." }` to `/api/sso/service-sso` with JSON content and
`Accept`, `User-Agent`, `Origin`, and `Referer` headers. `Origin` is
`CONECTA_SITE`; `Referer` is `CONECTA_CLIENT_DOMAIN` when configured, or the
current Decidim request host otherwise. It uses the returned
`result.data.clientdomain` and `result.data.clienttype` in the `/sso/login` URL.
Panamá Conecta returns to the
registered callback URL with a `token` query parameter. The strategy preserves
that token exactly as it appears in the raw query string (including `+`), then
posts it as a Bearer token to `/api/user/user-info`.

The current user-info response maps `user_id` to OmniAuth's UID,
`nombre_completo` to the name, and `correo_electronico` to the email. Only
whitelisted profile fields are exposed as `raw_info`; credentials and returned
token fields are not retained in the OmniAuth auth hash.

**Callback CSRF limitation:** Panamá Conecta does not currently return the
OmniAuth `state` value, and the strategy's state comparison is disabled. This
must be resolved before production use, either by having AIG return a
per-sign-in correlation value or by reviewing a suitable alternative.
