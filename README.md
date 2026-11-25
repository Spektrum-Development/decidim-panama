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

## Setting up the application

You will need to do some steps before having the app working properly once you have deployed it:

1. Create a System Admin user: `bin/rails decidim_system:create_admin`
1. Visit `<your app url>/system` and log in with your system admin credentials
1. Create a new organization. Check the locales you want to use for that organization, and select a default locale.
1. Set the correct default host for the organization, otherwise the app will not work properly. Note that you need to include any subdomain you might be using.
1. Fill the rest of the form and submit it.

You are good to go!
