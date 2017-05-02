module Utils
  # Utility methods for interacting with Sensu
  module Sensu
    def calculate_expiration(duration, units)
      if units
        expiration = case units
                     when 's'
                       duration
                     when 'm'
                       duration * 60
                     when 'h'
                       duration * 3600
                     when 'd'
                       duration * 3600 * 24
                     end
        human_duration = "#{duration}#{units}"
      else
        expiration = 3600
        human_duration = '1h'
      end
      [expiration, human_duration]
    end

    def check_alias(client, check)
      "#{client}:#{check && !check.empty? ? check : '*'}"
    end

    def sorted_by(body, attribute)
      MultiJson.load(body, symbolize_keys: true).sort do |a, b|
        a[attribute.to_sym] <=> b[attribute.to_sym]
      end
    end

    def sorted_events(body)
      MultiJson.load(body, symbolize_keys: true).sort do |a, b|
        a[:client][:name] <=> b[:client][:name]
      end
    end

    def silence_post_data(user, expiration, client, check)
      data = {
        creator: user.name,
        expire: expiration,
        reason: 'Because Lita says so!',
        subscription: "client:#{client}"
      }
      data[:check] = check if !check.nil? && check != ''
      MultiJson.dump(data)
    end

    private

    def add_domain(client)
      if config.domain && !client.include?(config.domain)
        if config.domain[0, 1] == '.'
          client + config.domain
        else
          client + '.' + config.domain
        end
      else
        client
      end
    end
  end
end
