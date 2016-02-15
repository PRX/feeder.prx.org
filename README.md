# Feeder
[![License](https://img.shields.io/badge/license-AGPL-blue.svg)](https://www.gnu.org/licenses/agpl-3.0.html)
[![Build Status](https://travis-ci.org/PRX/feeder.prx.org.svg)](https://travis-ci.org/PRX/feeder.prx.org)
[![Code Climate](https://codeclimate.com/github/PRX/feeder.prx.org/badges/gpa.svg)](https://codeclimate.com/github/PRX/feeder.prx.org)
[![Coverage Status](https://coveralls.io/repos/PRX/feeder.prx.org/badge.svg)](https://coveralls.io/r/PRX/feeder.prx.org)
[![Dependency Status](https://gemnasium.com/PRX/feeder.prx.org.svg)](https://gemnasium.com/PRX/feeder.prx.org)

## Description
This Rails app provides the Feeder service.
It follows the [standards for PRX services](https://github.com/PRX/meta.prx.org/wiki/Project-Standards#services).

It generates RSS feeds based on stories and their podcast specific data.
It can also generate RSS feeds based on existing (Media)RSS feeds.
It provides an API for information about feed items.

## Integrations & Dependencies
- postgres - main database
- cms.prx.org - get data about episodes
- id.prx.org - get token for protected cms requests
- fixer.prx.org - send tasks to analyze and manipulate audio files
- crier.prx.org - receive updates about podcasts and episodes
- dovetail.prxu.org - calls feeder for info about episodes

## Installation
These instructions are written assuming Mac OS X install.

### Basics
```
# Homebrew - http://brew.sh/
ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"

# Git - http://git-scm.com/
brew install git
```

### Docker Development
You can now build and run the feeder application using docker.
We're using Docker for deployment, so this is also a good way to make sure
Development and production environments match as much as possible.

#### Prerequisites
[Install Dinghy and related projects](https://github.com/codekitchen/dinghy)
Notes:
* Using 'VirtualBox' is recommended.
* Also be sure to install `docker-compose` along with the toolbox

#### Install Feeder
```
# Get the code
git clone git@github.com:PRX/feeder.prx.org.git
cd feeder.prx.org

# Make .env, start with the example and edit to include AWS & other credentials
cp env-example .env
vim .env

# Build the `feeder` container, it will be used for `web` and `worker`
docker-compose build

# Start the postgres `db`
docker-compose start db

# ... and run migrations against it
docker-compose run feeder migrate

# Create SQS (and SNS) configuration
docker-compose run feeder sqs

# Test
docker-compose run feeder test

# Guard
docker-compose run feeder guard

# Run the web, worker, and db
docker-compose up
```

### Local Rails/Ruby Development
If docker is not your style, you can also run as a regular local Rails application.
```
# Pow to serve the app - http://pow.cx/
curl get.pow.cx | sh

brew update

# rbenv and ruby-build - https://github.com/sstephenson/rbenv
brew install rbenv ruby-build
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
echo 'eval "$(rbenv init -)"' >> ~/.bash_profile
source ~/.bash_profile

# ruby (.ruby-version default)
rbenv install

# bundler and powder gem - http://bundler.io/
gem install bundler powder
```

### Rails Project
Consider forking the repo if you plan to make changes, otherwise you can clone it:
```
# ssh repo syntax (or https `git clone https://github.com/PRX/feeder.prx.org.git feeder.prx.org`)
git clone git@github.com:PRX/feeder.prx.org.git feeder.prx.org
cd feeder.prx.org

# bundle to install gems dependencies
bundle install

# copy the env-example, change values if necessary
cp env-example .env

# create databases
be rake db:create
be rake db:create RAILS_ENV=test
bundle exec rake db:migrate

# run tests
bundle exec rake

# pow set-up
powder link

# see the development status page
open http://feeder.prx.dev
```

## Build and Deploy Scripts
The scripts will not create the entire deployment environment, but they will
help in a few ways.

### Prerequisites
You will need to copy and will out the deploy-example file:
```
cp deploy-example .deploy
vi .deploy
```

When building and deploying a new version, you'll need to increment the version.

You also need to install the AWS CLI and `jq`:
```
pip install awscli
brew install jq
```

### Scripts
The available scripts will do the following:

* Create the task definitions for the first time setup of the services
You need a `.env.staging` file for staging, and `env.production` for production.
```
# create the staging defs
container/create-task-definitions.sh

# create the production defs
ENV=production container/create-task-definitions.sh
```

* Build the image and same it with the version number to ECR
```
container/build-image.sh
```

* Update the services with the latest build
```
# Deploy to staging
container/deploy.sh

# Deploy to production
ENV=production container/deploy.sh
```

## Audio Handling

When a new file episode is inserted, the audio files for it (either from `enclosure` or `media:content` tags) are also inserted as `media_resource` records. For each resource, a copy task is created to move the audio to the s3 bucket where it can be served by the CDN.

When an episode has a new audio url, that is considered a new file, and the old one is deleted and a new `media_resource` is added, with a new copy task.

## License
[AGPL License](https://www.gnu.org/licenses/agpl-3.0.html)

## Contributing
Completing a Contributor License Agreement (CLA) is required for PRs to be accepted.
