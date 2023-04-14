# Feeder

![GitHub branch checks state](https://img.shields.io/github/checks-status/PRX/feeder.prx.org/main)
[![License](https://img.shields.io/badge/license-AGPL-blue.svg)](https://www.gnu.org/licenses/agpl-3.0.html)
[![Lint](https://github.com/PRX/feeder.prx.org/actions/workflows/lint.yml/badge.svg)](https://github.com/PRX/feeder.prx.org/actions/workflows/lint.yml?query=branch%3Amain)

## Description

Rails app to manage PRX podcasts and generate RSS feeds.

Includes both an HTML user interface and a [HAL API](https://en.wikipedia.org/wiki/Hypertext_Application_Language).

This repo follows the [standards for PRX services](https://github.com/PRX/docs.prx.org/blob/master/team/Project-Standards.md#services).

## Dependencies

### Tech

- Ruby - runs all the things!
- PostgreSQL - main database
- AWS S3 - writing RSS files
- AWS SQS - async job queue
- NodeJS - for linting

### Integrations

This app additionally relies on other PRX services:

- [id.prx.org](https://id.prx.org) - authorize PRX users/accounts
- [Porter](https://github.com/PRX/Porter) - send tasks to analyze and manipulate audio/image files
- [dovetail.prxu.org](https://dovetail.prxu.org) - calls feeder for info about episodes/feeds
- [Apple API Bridge Lambda](https://github.com/PRX/api-bridge-lambda/) - for publishing subscribable podcasts to Apple

## Installation

First off, clone the repo and get ruby/nodejs installed.
Try [asdf](https://asdf-vm.com/), or use something completely different!

```sh
git clone git@github.com:PRX/feeder.prx.org.git
cd feeder.prx.org

# make your local git blame ignore giant linting commits
git config --global blame.ignoreRevsFile .git-blame-ignore-revs

# sane ENV defaults
cp env-example .env

# install tools
asdf install

# rubygems
bundle install

# node packages
npm install

# Configure puma-dev
echo 3002 > ~/.puma-dev/feeder.prx
```

You'll also want a postgres server running. Try [DBngin](https://dbngin.com/), or you know,
do your own thing.

### Configuration

The `env-example` file has some sane defaults, but you'll need to change a few values in your `.env`:

1. `POSTGRES_DATABASE` - leave as `feeder_development`, but ensure it already exists or your db user has create privileges (and run `bin/rails db:create`)
2. `POSTGRES_PASSWORD` - set to your local db user's password
3. `POSTGRES_USER` - set to your local db username
4. `PRX_CLIENT_ID` - a valid **client application** key from ID. If `ID_HOST`, for example, is set to `id.staging.prx.tech`, get this key from [there](https://id.staging.prx.tech/admin/client_applications). The `Url` should match the domain you plan to use to access the site locally (e.g., `feeder.prx.test`).

There are a bunch of other ENVs you may want to set, depending on what you're developing.
But these are the minimum.

### Database Setup

If you're cool with a blank database, just run the migrations!

```sh
bin/rails db:migrate
```

Otherwise, it can be helpful to have a staging or production database to get started. First
off, make sure you have our [homebrew dev tools](https://github.com/PRX/homebrew-dev-tools) installed,
and you can successfully connect to the stag/prod environments via `awstunnel`.

Then, set `DUMP_REMOTE_POSTGRES_USER` and `DUMP_REMOTE_POSTGRES_DATABASE` in your `.env`, for the
staging or prod database you're copying.

```sh
# start staging tunnel
awstunnel stag

# in another tab, dump the database
ops/bin/dump_db.sh stag

# restore it to a clone db
ops/bin/setup_clone_db.sh

# and copy the clone to feeder_development
ops/bin/load_db.sh

# and if you ever need a fresh db, run it again
ops/bin/load_db.sh
```

## Development

Create a branch and/or fork the repo if you plan to make changes.

Branch names should start with `feat/` `fix/` `chore/`, depending on the kind of changes you'll be making.

```sh
git checkout -b feat/this_is_my_new_feature
```

### Server

Run the rails development server at [feeder.prx.test](http://feeder.prx.test):

```sh
bin/rails server
```

At [feeder.prx.test/fake](http://feeder.prx.test/fake), you'll find the HTML user
interface for Feeder. In addition to standard Rails, it uses [Turbo](https://turbo.hotwired.dev/),
[Stimulus](https://stimulus.hotwired.dev/), and [Bootstrap 5](https://getbootstrap.com/docs/5.0/getting-started/introduction/).
Whenever possible, we'd appreciate it if you stuck to this toolset!

When you land on an authenticated page, you will be redirected to `ID_HOST` for authorization.
Once you are logged in, you will be redirected back to (hopefully) your local `/auth/sessions`.
If this is not working, you should check your `PRX_CLIENT_ID` ClientApplication and your
`AccountApplication`s in the ID admin interface.

#### HAL API

At [feeder.prx.test/api/v1](http://feeder.prx.test/api/v1), you'll find the HAL API root.
You can navigate around the public API endpoints by following the links. This is currently
built with the [hal_api-rails](https://github.com/PRX/hal_api-rails) gem, but we have plans
to eventually switch to [halbuilder](https://github.com/PRX/halbuilder) (an extension of Jbuilder).

For `/api/v1/authorization` endpoints, you will need to provide a [JWT](https://jwt.io/) provided by
PRX ID.

### Worker

In addition to the server, Feeder runs a worker for processing async jobs. This largely uses
the [Shoryuken](https://github.com/ruby-shoryuken/shoryuken) gem and AWS SQS.

Some jobs run completely in Ruby, while others will call out to [Porter](https://github.com/PRX/Porter)
or the [Apple API Bridge Lambda](https://github.com/PRX/api-bridge-lambda/) to complete their work.

First, make sure you have [awsso](https://github.com/PRX/internal/wiki/AWS:-Developer-Access-%E2%80%93-CLI#sso-via-iam-identity-center)
installed and working, along with an AWS profile for the prx-shared-development account (`sso_account_id = 556402616001`).

Then you'll need to set a few ENVs to make this all work:

```
# use prx-shared-development account
AWS_ACCOUNT_ID=556402616001

# and SQS that start with your name
ANNOUNCE_RESOURCE_PREFIX=<yourname>

# and staging Porter
PORTER_SNS_TOPIC=<get from legacy SNS web console>

# configure EvaporateJS uploads
UPLOAD_BUCKET_NAME=prx-feed-development
UPLOAD_BUCKET_PREFIX=uploads
UPLOAD_SIGNING_SERVICE_KEY_ID=<get this from prx-shared-development IAM web console>
UPLOAD_SIGNING_SERVICE_URL=<get this from prx-shared-development Lambda web console>

# use the development S3/CloudFront for that same bucket
FEEDER_CDN_HOST=f.development.prxu.org
FEEDER_STORAGE_BUCKET=prx-feed-development
```

This will set you up to use the `prx-feed-development` bucket for both uploads and the final destination
for processed files. Then, to start the worker in development:

```sh
# use the prx-shared-development account - both for running workers and webs
export AWS_PROFILE=prx-shared-development

# you'll need to create the SQS queues the first time
bin/rails sqs:create

# now you can start the web/worker in different terminals
bin/rails web
bin/rails worker

# or shorthand
bin/rails s
bin/rails w
```

#### File Handling

When an episode is created or updated, the image and audio files (either from `enclosure` or `media:content` tags) are also inserted as `podcast_image`, `episode_image`, and `media_resource` records.
For each resource, a copy task is created to add the files to the s3 bucket for CDN serving.

When an episode file has a new original url, that is considered a new file. When this happens, the old file is left in place, and a new resource inserted for the new original url. Once the new resource has processed (e.g. been copied), it is marked as complete, and the old resource is deleted.

### Tests

You should write/run the tests! With any PR, we expect some tests for your changes.

```sh
bin/rails test
bin/rails test test/models/podcast_test.rb
bin/rails test test/models/podcast_test.rb:9
```

### Linting

This entire repo is linted using:

- [standardrb](https://github.com/testdouble/standard) for ruby files
- [erblint](https://github.com/Shopify/erb-lint) for `html.erb` files
  - Note this _does not_ handle indentation at the moment, but you're encouraged to
    use some other editor plugin to ensure your erb has the right indentation
- [prettier](https://prettier.io/) for `js`, `scss`, and `md` files

Your commits will be checked with these in Github, so you should lint your code before pushing.

```sh
bin/rails lint
bin/rails lint:fix
```

TODO: editor integration. Because format-on-save is cool.

## License

[AGPL License](https://www.gnu.org/licenses/agpl-3.0.html)

## Contributing

Completing a Contributor License Agreement (CLA) is required for PRs to be accepted.
