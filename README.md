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

The Panamá Conecta OmniAuth provider is enabled when `PANAMA_CONECTA_CLIENT_ID`
and `PANAMA_CONECTA_CLIENT_SECRET` are set. The same `clientSecretToken`
provided by Panamá Conecta is used as the login `accessToken` and as the
`X-Client-Secret` header when validating the returned user token.

| Environment variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `PANAMA_CONECTA_CLIENT_ID` | Yes | — | Registered client ID; sent as `X-Client-Id` during user validation. |
| `PANAMA_CONECTA_CLIENT_SECRET` | Yes | — | Registered `clientSecretToken`; used for login and user validation. |
| `PANAMA_CONECTA_CLIENT_DOMAIN` | No | Current request base URL | Registered client domain sent as `ownDomain`. Set this to the exact `clientDomain` provided by Panamá Conecta when possible. |
| `PANAMA_CONECTA_SITE` | No | "" | Panamá Conecta login site. |
| `PANAMA_CONECTA_API_SITE` | No | "" | API base URL used to validate the returned user token. |
| `PANAMA_CONECTA_APP_TYPE` | No | `web` | Application type passed to the login service, such as `web` or `desktop`. |

Register the callback URL `<clientDomain>/users/auth/panama_connecta/callback` with Panamá Conecta.
The OmniAuth middleware handles `/sso/userinfo` with or without the trailing
slash. The sign-in button uses OmniAuth's normal request route for
`panama_conecta`.

Example environment configuration (keep real credentials in a private
environment file or secret manager, not in source control):

```sh
PANAMA_CONECTA_CLIENT_ID=your-client-id
PANAMA_CONECTA_CLIENT_SECRET=your-client-secret-token
PANAMA_CONECTA_CLIENT_DOMAIN=https://your-decidim-domain.example
# Panamá Conecta environment URLs:
PANAMA_CONECTA_SITE=https://the-panama-conecta-domain
PANAMA_CONECTA_API_SITE=https://the-panama-conect-api-domain
# PANAMA_CONECTA_APP_TYPE=web
```

The registered client domain can be left unset when the app's request host is
the same as the domain registered with Panamá Conecta. The strategy uses this
domain directly for `ownDomain` and skips the `service-sso` lookup, which may
return a browser-only Imperva/TSPD verification page to server-side requests.
