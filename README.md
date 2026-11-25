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
