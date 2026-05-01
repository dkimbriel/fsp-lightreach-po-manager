module Lightreach
    class Client
        attr_reader :base_url, :auth_uri, :access_token

        def self.instance
            @instance ||= new
        end

        def initialize
            set_urls
            set_credentials
            @access_token = fetch_access_token
            @headers = {
                'Authorization' => "Bearer #{@access_token}",
                'Content-Type' => 'application/json'
            }
        end

        def set_urls
            @base_url = 'https://next.palmetto.finance/api'
            @auth_uri = URI('https://next.palmetto.finance/api/auth/login')
            @base_url = 'https://palmetto.finance/api' if Rails.env.production?
            @auth_uri = URI('https://palmetto.finance/api/auth/login') if Rails.env.production?
        end

        def set_credentials
            creds = Rails.application.credentials.lightreach[:next]
            creds = Rails.application.credentials.lightreach[:production] if Rails.env.production?
            @username = creds[:username]
            @password = creds[:password]
        end

        def fetch_access_token
            body = { username: @username, password: @password }
            response = HttpVerb.post(@auth_uri, body)
            parse_response(response, @auth_uri.to_s, body)['access_token']
        end

        def get(path)
            uri = URI("#{@base_url}#{path}")
            puts uri
            response = HttpVerb.get(uri, headers: @headers)
            parse_response(response, uri.to_s, nil)
        end

        def patch(path, body)
            uri = URI("#{@base_url}#{path}")
            response = HttpVerb.patch(uri, body, headers: @headers)
            parse_response(response, uri.to_s, body)
        end

        def post(path, body)
            uri = URI("#{@base_url}#{path}")
            response = HttpVerb.post(uri, body, headers: @headers)
            parsed = parse_response(response, uri.to_s, body)
            check_for_error(parsed, path, body)
            parsed
        end

        def parse_response(response, uri, request_body)
            response_body = response&.body
            response_code = response&.code

            if response.nil?
                Sentry.capture_message(
                    'Lightreach API: nil response',
                    level: :error,
                    extra: sentry_context(uri, request_body, nil, nil)
                )
                return {}
            end

            JSON.parse(response_body)
        rescue JSON::ParserError => e
            Sentry.capture_exception(e, extra: sentry_context(uri, request_body, response_code, response_body))
            {}
        rescue StandardError => e
            Sentry.capture_exception(e, extra: sentry_context(uri, request_body, response_code, response_body))
            {}
        end

        def sentry_context(uri, request_body, response_code, response_body)
            {
                request_uri: uri,
                request_body: truncate_for_sentry(request_body),
                response_code: response_code,
                response_body: truncate_for_sentry(response_body)
            }
        end

        def truncate_for_sentry(value, max_length: 2000)
            return nil if value.nil?

            str = value.is_a?(String) ? value : value.to_json
            str.length > max_length ? "#{str[0...max_length]}...[truncated]" : str
        end

        def check_for_error(response, path, body)
            return unless response.is_a?(Hash) && response['error'].present?

            Sentry.capture_message(
                "Lightreach API error: #{response['error']}",
                level: :error,
                extra: { path: path, body: body, response: response }
            )
        end

        def multipart_post(path, document)
            uri = URI("#{@base_url}#{path}")
            response = HttpVerb.post_multipart_form(uri, document, headers: @headers)
            doc_context = { type: document[:type], grouped: document[:grouped] }
            parsed = parse_response(response, uri.to_s, doc_context)
            check_for_error(parsed, path, doc_context)
            parsed
        end
    end

    class Account
        def self.find(account_id)
            client = Lightreach::Client.new
            client.get("/accounts/#{account_id}")
        end

        def self.update(account_id, body)
            client = Lightreach::Client.new
            client.patch("/accounts/#{account_id}", body)
        end
    end

    class InstallPackage
        def self.save(account_id, install_package)
            client = Lightreach::Client.new
            client.post("/v2/accounts/#{account_id}/install-package/save", install_package)
        end
    end

    class ActivationPackage
        def self.save(account_id, activation_package)
            client = Lightreach::Client.new
            client.post("/v2/accounts/#{account_id}/activation-package/save", activation_package)
        end
    end

    class Document
        def self.upload(account_id, document)
            client = Lightreach::Client.new
            client.multipart_post("/accounts/#{account_id}/documents", document)
        end
    end

    class Pricing
        def self.list(account_id)
            client = Lightreach::Client.new
            client.get("/v2/accounts/#{account_id}/pricing")
        end
    end

    class Adders
        def self.available(account_id)
            client = Lightreach::Client.new
            client.get("/v2/accounts/#{account_id}/available-adders")
        end
    end

    class Quote
        def self.list(account_id)
            client = Lightreach::Client.new
            client.get("/v3/accounts/#{account_id}/quotes")
        end
    end

    class EstimatedPricing
        def self.create(body)
            client = Lightreach::Client.new
            client.post('/v3/estimated-pricing', body)
        end

        def self.test
            create(
                {
                    lseId: 3010,
                    state: 'TX',
                    systemSizeKw: 9.3,
                    systemFirstYearProductionKwh: 12000,
                    electricalUpgradeIncluded: false
                }
            )
        end
    end

    class SystemDesign
        def self.current(account_id)
            client = Lightreach::Client.new
            client.get("/accounts/#{account_id}/system-design/current")
        end
    end
end
