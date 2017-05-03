# lita-sensu2

[![Gem Version](http://img.shields.io/gem/v/lita-sensu2.svg)](https://rubygems.org/gems/lita-sensu2)
[![Build Status](https://travis-ci.org/knuedge/lita-sensu2.png?branch=master)](https://travis-ci.org/knuedge/lita-sensu2)
[![Coverage Status](https://coveralls.io/repos/knuedge/lita-sensu2/badge.png)](https://coveralls.io/r/knuedge/lita-sensu2)

A maintained Lita handler for working with the [Sensu](http://sensuapp.org) monitoring framework.

**Note**: This handler requires Lita >= 4.7.
## Installation

Add lita-sensu2 to your Lita instance's Gemfile:

``` ruby
gem 'lita-sensu2'
```

## Configuration

The sensu handler needs to be configured with information about your sensu
installation.  Add the following configuration to your `lita_config.rb`.  All
parameters are optional, by default the handler will connect to 127.0.0.1:4567
for the sensu API service.

```ruby
config.handlers.sensu2.api_url = '127.0.0.1'
config.handlers.sensu2.api_port = 4567
config.handlers.sensu2.domain = 'mydomain.com'
```

## Usage

Available commands:

`sensu client <client>` - Shows information on a specific client
`sensu client <client> history` - Shows history information for a specific client
`sensu clients` - List sensu clients
`sensu events` [for <client>] - Shows current events, optionally for only a specific client
`sensu info` - Displays sensu information
`sensu remove client <client>` - Remove client from sensu
`sensu resolve event <client>[/service]` - Resolve event/all events for client
`sensu silence <hostname>[/<check>][ for <duration><units>]` - Silence event
`sensu silences` - List current silences
`sensu stashes` - Displays current sensu stashes

## License

[Apache-2.0](http://opensource.org/licenses/Apache-2.0)
