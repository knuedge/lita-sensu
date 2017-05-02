module Utils
  # Utility methods for making HTTP requests for Sensu
  module SensuHTTP
    def headers
      headers = {}
      if config.api_user
        creds = Base64.encode64("#{config.api_user.chomp}:#{config.api_pass.chomp}")
        headers['Authorization'] = "Basic #{creds}"
      end
      headers
    end

    def http_get(url)
      http.get(url) do |req|
        req.headers = headers
      end
    end

    def http_delete(url)
      http.delete(url) do |req|
        req.headers = headers
      end
    end

    def http_post(url, data)
      http.post(url, data) do |req|
        req.headers = headers
      end
    end

    def silence_url
      "#{config.api_url}:#{config.api_port}/silenced"
    end
  end
end
