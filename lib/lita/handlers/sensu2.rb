require 'time'

module Lita
  module Handlers
    class Sensu2 < Handler
      include Utils::Sensu
      include Utils::SensuHTTP
      # Handle errors
      # https://github.com/MrTin/lita-chuck_norris/blob/master/lib/lita/handlers/chuck_norris.rb

      config :api_url, default: '127.0.0.1', type: String
      config :api_port, default: 4567, type: Integer
      config :domain, type: String
      config :api_user, type: String
      config :api_pass, type: String

      route(
        /sensu client ([^\s]*$)/,
        :client,
        help: { 'sensu client <client>' => 'Shows information on a specific client' }
      )

      route(
        /sensu client ([^\s]*) history/,
        :client_history,
        help: {
          'sensu client <client> history' => 'Shows history information for a specific client'
        }
      )

      route(
        /sensu clients/,
        :clients,
        help: { 'sensu clients' => 'List sensu clients' }
      )

      route(
        /sensu events(?: for (.*))?/,
        :events,
        help: {
          'sensu events [for <client>]' => 'Shows current events, optionally for a specific client'
        }
      )

      route(
        /sensu info/,
        :info,
        help: { 'sensu info' => 'Displays sensu information' }
      )

      route(
        /(?:sensu\s+)?remove client (.*)/,
        :remove_client,
        help: { 'sensu remove client <client>' => 'Remove client from sensu' }
      )

      route(
        %r{(?:sensu\s+)?resolve event (.*)(?:/)(.*)},
        :resolve,
        help: { 'sensu resolve event <client>[/service]' => 'Resolve event/all events for client' }
      )

      route(
        %r{(?:sensu\s+)?silence ([^\s/]*)(?:/)?([^\s]*)?(?: for (\d+)(\w))?},
        :silence,
        help: { 'sensu silence <hostname>[/<check>][ for <duration><units>]' => 'Silence event' }
      )

      route(
        /^sensu silences$/,
        :silences,
        help: { 'sensu silences' => 'Displays current sensu silences' }
      )

      route(
        /sensu stash(es)?/,
        :stashes,
        help: { 'sensu stashes' => 'Displays current sensu stashes' }
      )

      def client(response)
        client = add_domain(response.matches[0][0])
        client_url = "#{config.api_url}:#{config.api_port}/clients/#{client}"
        resp = http_get(client_url)
        if resp.status == 200
          client = MultiJson.load(resp.body, symbolize_keys: true)
          response.reply(MultiJson.dump(client, pretty: true))
        elsif resp.status == 404
          response.reply("#{client} was not found")
        else
          log.warn "Sensu returned an internal error fetching #{client_url}"
          response.reply("An error occurred fetching client #{client}")
        end
      end

      def client_history(response)
        client = add_domain(response.matches[0][0])
        client_url = "#{config.api_url}:#{config.api_port}/clients/#{client}/history"
        resp = http_get(client_url)
        if resp.status == 200
          response.reply(render_template('client_history', history: sorted_by(resp.body, :check)))
        else
          log.warn("Sensu returned an internal error fetching #{client_url}")
          response.reply("An error occurred fetching client #{client} history")
        end
      end

      def clients(response)
        clients_url = "#{config.api_url}:#{config.api_port}/clients"
        resp = http_get(clients_url)
        if resp.status == 200
          response.reply(render_template('clients', clients: sorted_by(resp.body, :name)))
        else
          log.warn("Sensu returned an internal error fetching #{clients_url}")
          response.reply('An error occurred fetching clients')
        end
      end

      def events(response)
        client = response.matches[0][0] ? '/' + add_domain(response.matches[0][0]) : ''
        client_url = "#{config.api_url}:#{config.api_port}/events#{client}"

        resp = http_get(client_url)
        response.reply(
          if resp.status == 200
            render_template('events', events: sorted_events(resp.body))
          else
            log.warn("Sensu returned an internal error fetching #{client_url}")
            'An error occurred fetching clients'
          end
        )
      end

      def info(response)
        resp = http_get("#{config.api_url}:#{config.api_port}/info")
        raise RequestError unless resp.status == 200
        info = MultiJson.load(resp.body, symbolize_keys: true)
        response.reply(MultiJson.dump(info, pretty: true))
      end

      def remove_client(response)
        client = add_domain(response.matches[0][0])
        client_url = "#{config.api_url}:#{config.api_port}/clients/#{client}"
        resp = http_delete(client_url)
        if resp.status == 202
          response.reply("#{client} removed")
        elsif resp.status == 404
          response.reply("#{client} was not found")
        else
          log.warn("Sensu returned an internal error deleting #{client_url}")
          response.reply("An error occurred removing #{client}")
        end
      end

      def resolve(response)
        client = add_domain(response.matches[0][0])
        check = response.matches[0][1]
        res_url = "#{config.api_url}:#{config.api_port}/resolve"

        data = { client: client, check: check }
        post_data = MultiJson.dump(data)
        resp = http_post(res_url, post_data)
        if resp.status == 202
          response.reply("#{client}/#{check} resolved")
        elsif resp.status == 400
          response.reply("Resolve message was malformed: #{post_data}")
        elsif resp.status == 404
          response.reply("#{client}/#{check} was not found")
        else
          log.warn(
            "Sensu returned an internal error resolving #{res_url} with #{post_data}"
          )
          response.reply("There was an error resolving #{client}/#{check}")
        end
      end

      def silence(response)
        client = add_domain(response.matches[0][0])
        check = response.matches[0][1]
        duration = response.matches[0][2]
        units = response.matches[0][3]

        expiration, human_duration = calculate_expiration(duration.to_i, units)

        return false unless valid_expiration(response, expiration, units)

        post_data = silence_post_data(response.user, expiration, client, check)
        resp = http_post(silence_url, post_data)
        response.reply silence_post_msg(resp, post_data, human_duration, check_alias(client, check))
      end

      def silences(response)
        resp = http_get(silence_url)
        if resp.status == 200
          response.reply(render_template('silences', silences: sorted_by(resp.body, :subscription)))
        else
          log.warn("Sensu returned an internal error resolving #{silence_url}")
          response.reply('An error occurred fetching silences')
        end
      end

      def stashes(response)
        stashes_url = "#{config.api_url}:#{config.api_port}/stashes"
        resp = http_get(stashes_url)
        if resp.status == 200
          response.reply(render_template('stashes', stashes: sorted_by(resp.body, :name)))
        else
          log.warn("Sensu returned an internal error resolving #{stashes_url}")
          response.reply('An error occurred fetching stashes')
        end
      end

      private

      def silence_post_msg(resp, post_data, human_duration, chk_alias)
        if resp.status == 201
          "#{chk_alias} silenced for #{human_duration}"
        else
          log.warn(
            "Sensu returned an internal error posting '#{post_data}' to #{silence_url}"
          )
          "An error occurred silencing to #{chk_alias}"
        end
      end

      def valid_expiration(response, exp, units)
        return true if exp
        response.reply(
          "Unknown unit (#{units}).  I know s (seconds), m (minutes), h (hours), and d(days)"
        )
        false
      end
    end

    Lita.register_handler(Sensu2)
  end
end
