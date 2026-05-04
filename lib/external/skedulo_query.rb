class SkeduloQuery
    class GraphQLError < StandardError; end

    @@skedulo_api_uri = URI("https://api.skedulo.com/graphql/graphql")
    # Always use production Skedulo API key
    @@skedulo_api_key = Rails.application.credentials.SKEDULO_API_KEY_PRODUCTION

    @@headers = { "Authorization" => "Bearer #{@@skedulo_api_key}" }

    def self.send(query, variables)
        body = {
            "query" => query,
            "variables" => variables
        }

        response = HttpVerb.post(@@skedulo_api_uri, body, headers: @@headers)
        parsed = JSON.parse(response.body)

        if parsed["errors"].present?
            error_messages = parsed["errors"].map { |e| e["message"] }.join("; ")
            raise GraphQLError, "Skedulo GraphQL error: #{error_messages}"
        end

        parsed
    end
end
