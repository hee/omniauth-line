require 'faraday'
require 'logger'

module OAuth2
  class Client

    # Makes a request relative to the specified site root.
    #
    # @param [Symbol] verb one of :get, :post, :put, :delete
    # @param [String] url URL path of request
    # @param [Hash] opts the options to make the request with
    # @option opts [Hash] :params additional query parameters for the URL of the request
    # @option opts [Hash, String] :body the body of the request
    # @option opts [Hash] :headers http request headers
    # @option opts [Boolean] :raise_errors whether or not to raise an OAuth2::Error on 400+ status
    #   code response for this request.  Will default to client option
    # @option opts [Symbol] :parse @see Response::initialize
    # @yield [req] The Faraday request
    def request(verb, url, opts = {}) # rubocop:disable CyclomaticComplexity, MethodLength
      connection.response :logger, ::Logger.new($stdout) if ENV['OAUTH_DEBUG'] == 'true'

      url = connection.build_url(url, opts[:params]).to_s

      # replace to api.line.me
      response = connection.run_request(verb, url.sub('access.line.me', 'api.line.me'), opts[:body], opts[:headers]) do |req|
        yield(req) if block_given?
      end
      response = Response.new(response, :parse => opts[:parse])

      case response.status
      when 301, 302, 303, 307
        opts[:redirect_count] ||= 0
        opts[:redirect_count] += 1
        return response if opts[:redirect_count] > options[:max_redirects]
        if response.status == 303
          verb = :get
          opts.delete(:body)
        end
        request(verb, response.headers['location'], opts)
      when 200..299, 300..399
        # on non-redirecting 3xx statuses, just return the response
        response
      when 400..599
        error = Error.new(response)
        fail(error) if opts.fetch(:raise_errors, options[:raise_errors])
        response.error = error
        response
      else
        error = Error.new(response)
        fail(error, "Unhandled status code value of #{response.status}")
      end
    end

  end
end
