Feeder
===============
[![License](https://img.shields.io/badge/license-AGPL-blue.svg)](https://www.gnu.org/licenses/agpl-3.0.html)
[![Build Status](https://travis-ci.org/PRX/feeder.prx.org.svg?branch=master)](https://travis-ci.org/PRX/feeder.prx.org)
[![Code Climate](https://codeclimate.com/github/PRX/feeder.prx.org/badges/gpa.svg)](https://codeclimate.com/github/PRX/feeder.prx.org)
[![Coverage Status](https://coveralls.io/repos/PRX/feeder.prx.org/badge.svg)](https://coveralls.io/r/PRX/feeder.prx.org)
[![Dependency Status](https://gemnasium.com/PRX/feeder.prx.org.svg)](https://gemnasium.com/PRX/feeder.prx.org)

Description
-----------
This Rails app provides the Feeder service.

It generates RSS feeds based on stories and their podcast specific data.

It follows the [standards for PRX services](https://github.com/PRX/meta.prx.org/wiki/Project-Standards#services).

Integrations & Dependencies
---------------------------
- postgres - main database
- cms.prx.org - get data about episodes

Installation
------------
These instructions are written assuming Mac OS X install.

### Basics
```
# Homebrew - http://brew.sh/
ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"

# Git - http://git-scm.com/
brew install git

# Pow to serve the app - http://pow.cx/
curl get.pow.cx | sh
```

### Ruby & Related Projects
```
brew update

# rbenv and ruby-build - https://github.com/sstephenson/rbenv
brew install rbenv ruby-build
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
echo 'eval "$(rbenv init -)"' >> ~/.bash_profile
source ~/.bash_profile

# ruby (.ruby-version default)
rbenv install

# bundler gem - http://bundler.io/
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

License
-------
[AGPL License](https://www.gnu.org/licenses/agpl-3.0.html)


Contributing
------------
Completing a Contributor License Agreement (CLA) is required for PRs to be accepted.
