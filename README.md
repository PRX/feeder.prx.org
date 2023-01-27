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
- NodeJS - for linting

### Integrations

This app additionally relies on other PRX services:

- [id.prx.org](https://id.prx.org) - authorize PRX users/accounts
- [Porter](https://github.com/PRX/Porter) - send tasks to analyze and manipulate audio/image files
- [dovetail.prxu.org](https://dovetail.prxu.org) - calls feeder for info about episodes/feeds

## Installation

First off, clone the repo and get ruby/nodejs installed.
Try [asdf](https://asdf-vm.com/), or use something completely different!

```sh
git clone git@github.com:PRX/feeder.prx.org.git
cd feeder.prx.org

# sane ENV defaults
cp env-example .env

# install tools
asdf install

# rubygems
bundle install

# node packages
npm install
```

You'll also want a postgres server running. Try [DBngin](https://dbngin.com/), or you know,
do your own thing.

### Configuration

The `env-example` file has some sane defaults, but you'll need to change a few values in your `.env`:

1. `POSTGRES_DATABASE` - leave as `feeder_development`, but ensure it already exists or your db user has create privileges (and run `bin/rails db:create`)
2. `POSTGRES_PASSWORD` - set to your local db user's password
3. `POSTGRES_USER` - set to your local db username
4. `PRX_CLIENT_ID` - set to a valid PRX client_application for `localhost:3002` development, in whatever `ID_HOST` you're using

There are a bunch of other ENVs you may want to set, depending on what you're developming.
But these are the minumum.

### Database Setup

If you're cool with a blank database, just run the migrations!

```sh
bin/rails db:migrate
```

Otherwise, it can be helpful to have a staging or production database to get started:

```sh
TBD
```

## Development

Create a branch and/or fork the repo if you plan to make changes.

Branch names should start with `feat/` `fix/` `chore/`, depending on the kind of changes you'll be making.

```sh
git checkout -b feat/this_is_my_new_feature
```

### Server

Run the rails development server at [localhost:3002](http://localhost:3002):

```sh
bin/rails server
```

### Worker

tbd

#### File Handling

When an episode is created or updated, the image and audio files (either from `enclosure` or `media:content` tags) are also inserted as `podcast_image`, `episode_image`, and `media_resource` records.
For each resource, a copy task is created to add the files to the s3 bucket for CDN serving.

When an episode file has a new original url, that is considered a new file. When this happens, the old file is left in place, and a new resource inserted for the new original url. Once the new resource has processed (e.g. been copied), it is marked as complete, and the old resource is deleted.

### Tests

tbd

### Linting

tbd

## License

[AGPL License](https://www.gnu.org/licenses/agpl-3.0.html)

## Contributing

Completing a Contributor License Agreement (CLA) is required for PRs to be accepted.
