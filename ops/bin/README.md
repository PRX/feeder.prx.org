---
FEEDER DATABASE DUMPING SCRIPTS
---

### Set up the environment

Make sure to set up the `PGUSER` and `PGHOST` env vars in your dotenv

```
DUMP_REMOTE_POSTGRES_USER=remote_postgres_username
DUMP_REMOTE_POSTGRES_DATABASE=remote_database_name
```

If you export those variables you should be able to run `psql` with no options.
Also, your user should have database create/drop permissions.

### Run the dump

In order:

1. ops/bin/dump_db.sh
2. ops/bin/setup_clone_db.sh
3. ops/bin/load_db.sh

Subsequently, if you need a fresh database you can run

```sh
ops/bin/load_db.sh
```
