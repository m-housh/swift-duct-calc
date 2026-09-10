# Self-hosting DuctCalc

The Compose configuration runs the production app and PostgreSQL. Install Podman
with a Compose provider, or Docker with Compose. Run the commands below from a
checkout of this repository, using a separate checkout and data directory for
each installation.

## Configure and start

Copy the environment example, then edit `docker/.env` before starting:

```sh
cp docker/example.env docker/.env
```

Set `POSTGRES_PASSWORD` to your own password. The app and database share the
`POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` values. Keep
`POSTGRES_HOSTNAME=db` for the supplied Compose network.

Set `COMPOSE_PROJECT_NAME` and `DUCTCALC_PORT` for this installation. The example
binds to `127.0.0.1`. For access through a domain, point a reverse proxy
with HTTPS at that address and port. To bind directly to a host network interface,
set `DUCTCALC_BIND_ADDRESS` to that interface's address.

Build the app from this checkout and start both services:

```sh
engine=podman
# Use engine=docker if Podman is unavailable.
"$engine" compose --env-file docker/.env -f docker/docker-compose.yaml up -d --build
"$engine" compose --env-file docker/.env -f docker/docker-compose.yaml ps
"$engine" compose --env-file docker/.env -f docker/docker-compose.yaml logs --tail=100 ductcalc
```

Open the configured address and port, or the domain provided by your reverse
proxy, and create an account. `/health` is the application health endpoint.
The app applies database migrations at startup.

To use the published image instead, set `DUCTCALC_IMAGE` in `docker/.env` to
`ghcr.io/m-housh/ductcalc:latest`, then run:

```sh
"$engine" compose --env-file docker/.env -f docker/docker-compose.yaml pull
"$engine" compose --env-file docker/.env -f docker/docker-compose.yaml up -d --no-build
```

The production image includes Poppler for CoolCalc imports and Pandoc/WeasyPrint
for PDF reports. Production uses PostgreSQL. Setting `SQLITE_PATH` does not switch
a production instance to SQLite; SQLite is used by the development environment.

## Admin dashboard

Create and confirm an account you control before adding its email to `ADMIN_EMAILS`
in `docker/.env`. Separate multiple addresses with commas; whitespace and case are
ignored. Recreate the app container with the updated environment, then sign in and
open `/admin` or Account > Admin. An empty list denies access to everyone.

```dotenv
ADMIN_EMAILS=admin@example.com,owner@example.com
AGGREGATE_METRICS_ENABLED=true
```

Each configured email must match exactly one existing account. Missing accounts,
malformed entries, and case-variant duplicate accounts prevent startup. Signup does
not verify email ownership, so the app resolves the configured emails to accounts
at startup instead of granting access to future signups. Update the list and
recreate the app container when changing admin access.

The dashboard stores daily aggregate activity locally, without account IDs,
emails, IP addresses, project details, or browsing histories in its metrics tables.
It adds no analytics cookies or scripts. Set `AGGREGATE_METRICS_ENABLED=false` and
recreate the app container to stop collection; current account/project totals and
previously collected history remain available. Activity rows are removed after 12
calendar months while the app and database are running, including when collection
is disabled. Backups follow your separate retention settings.

Keep reverse proxies and Cloudflare configured to respect the dashboard's
`Cache-Control: private, no-store` header and bypass caching for `/admin`, including
query variants. Visitor estimates remain separate in Cloudflare. These metrics do
not describe everything a proxy, framework log, or other service may collect;
review those settings and the generated privacy policy for your deployment.

## Data and updates

PostgreSQL persists data in `docker/data/` beside the Compose file. Recreating
containers preserves that directory. Keep it and `docker/.env` out of version
control. Changing the Compose project name alone does not isolate databases if
two instances mount the same data directory.

Back up before updating the app or database. For a logical database backup:

```sh
backup_dir="$HOME/ductcalc-backups"
mkdir -p "$backup_dir"
umask 077
"$engine" compose --env-file docker/.env -f docker/docker-compose.yaml exec -T db \
  sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  > "$backup_dir/ductcalc-$(date +%Y%m%d-%H%M%S).dump"
```

The backup is stored outside the checkout and contains account and project data.
Keep a copy of the deployment configuration separately. Changing PostgreSQL
credentials in `.env` does not change credentials in an initialized database.

For a source installation, update the checkout to the intended revision and rerun
`up -d --build`. For a published-image installation, rerun `pull` and
`up -d --no-build`. PostgreSQL major-version upgrades require their own data
migration; do not just change the database image tag against existing data.

To stop this installation while retaining its database:

```sh
"$engine" compose --env-file docker/.env -f docker/docker-compose.yaml down
```
