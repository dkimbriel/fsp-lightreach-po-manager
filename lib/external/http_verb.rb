module HttpVerb
    class Http
        def initialize(uri, limit: 5, multipart: false)
            @http = Net::HTTP.new(uri.host, uri.port)
            @http.use_ssl = uri.scheme == 'https'
            @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            @http.read_timeout = 500
            @limit = limit
            @prev_res = nil
            @multipart = multipart
            @form_data = nil
        end

        def set_form_data(form_data)
            @form_data = form_data
        end

        def close_files
            return unless @multipart

            @form_data.map do |row|
                file = row[1]
                file.close if file.respond_to?(:path) && file.respond_to?(:read)
            end
        end

        def try(limit)
            retries = 0
            begin
                yield
            rescue StandardError
                retry if (retries += 1) < limit
            end
        end

        def send(request)
            response = try(3) { @http.request(request.request) }
            response_code = response.code.to_i

            if response_code < 425
                close_files
                response
            elsif @limit.zero?
                puts "Response Code: #{response_code}, No retries left."
                puts 'Response Body:'
                puts @prev_res&.body if @prev_res.present?
                puts response.body unless @prev_res.present?
                @prev_res
            else
                puts "Response Code: #{response_code}, Retrying..."
                if response_code == 429
                    puts "Response Headers: #{response.to_hash}"
                    duration = response['Retry-After'] || 10
                    puts "Sleeping to avoid rolling limit: #{duration}"
                    sleep duration.to_i
                end
                @limit -= 1
                @prev_res = response
                send(request)
            end
        end
    end

    class Get
        attr_reader :request

        def initialize(uri, headers = nil)
            @request = Net::HTTP::Get.new(uri)
            @request['accept'] = '*/*'
            headers&.map { |k, v| @request[k] = v }
        end
    end

    class Delete
        attr_reader :request

        def initialize(uri, headers = nil)
            @request = Net::HTTP::Delete.new(uri)
            @request['accept'] = 'application/json'
            headers&.map { |k, v| @request[k] = v }
        end
    end

    class Post
        attr_reader :request

        def initialize(uri, body, headers = nil, content_type:)
            @request = Net::HTTP::Post.new(uri)
            if content_type != 'text/xml'
                @request['accept'] = 'application/json'
                body = body.to_json
            end
            @request['content-type'] = content_type
            @request.body = body
            headers&.map { |k, v| @request[k] = v }
        end
    end

    class MultipartPost
        attr_reader :request

        def initialize(uri, form_data, headers = nil)
            @request = Net::HTTP::Post.new(uri)
            @request.set_form form_data, 'multipart/form-data'
            @request['accept'] = 'application/json'
            headers&.map { |k, v| @request[k] = v }
        end
    end

    class PostForm
        attr_reader :request

        def initialize(uri, body, headers = nil)
            @request = Net::HTTP::Post.new(uri)
            @request['accept'] = 'application/json'
            @request['content-type'] = 'application/x-www-form-urlencoded'
            @request.body = URI.encode_www_form(body)
            headers&.map { |k, v| @request[k] = v }
        end
    end

    class Put
        attr_reader :request

        def initialize(uri, body, headers = nil)
            @request = Net::HTTP::Put.new(uri)
            @request['accept'] = 'application/json'
            @request['content-type'] = 'application/json'
            @request.body = body.to_json
            headers&.map { |k, v| @request[k] = v }
        end
    end

    class PutFile
        attr_reader :request

        def initialize(uri, path, headers = nil, content_type: nil)
            @request = Net::HTTP::Put.new(uri)
            @request['accept'] = 'application/json'
            @request['content-type'] =
                content_type || MIME::Types.type_for(path)&.first&.content_type || 'application/octet-stream'
            @request.body = File.read(path)
            headers&.map { |k, v| @request[k] = v }
        end
    end

    class PutForm
        attr_reader :request

        def initialize(uri, body, headers = nil)
            uri.query = URI.encode_www_form(body)
            @request = Net::HTTP::Put.new(uri)
            @request['accept'] = 'application/json'
            @request['content-type'] = 'application/x-www-form-urlencoded'
            @request.body = body.to_json
            headers&.map { |k, v| @request[k] = v }
        end
    end

    class Patch
        attr_reader :request

        def initialize(uri, body, headers = nil)
            @request = Net::HTTP::Patch.new(uri)
            @request['accept'] = 'application/json'
            @request['content-type'] = 'application/json'
            @request.body = body.to_json
            headers&.map { |k, v| @request[k] = v }
        end
    end

    class SimpleRequest
        attr_reader :request

        def initialize(request)
            @request = request
        end
    end

    def self.get(uri, headers: nil, limit: 5)
        http = Http.new(uri, limit: limit)
        request = Get.new(uri, headers)
        http.send(request)
    end

    def self.delete(uri, headers: nil, limit: 5)
        http = Http.new(uri, limit: limit)
        request = Delete.new(uri, headers)
        http.send(request)
    end

    def self.post(uri, body, headers: nil, limit: 5, content_type: 'application/json')
        http = Http.new(uri, limit: limit)
        request = Post.new(uri, body, headers, content_type: content_type)
        http.send(request)
    end

    # Something to think about here - the client needs to close any files after uploading.
    # Right now after calling http.send(request), inside of Http the client is handling the
    # closing of the files. This seems strange, and I think the MultipartPost class should
    # handle this. However, the MultipartPost instance has no idea when the request has been
    # resolved by the client.

    def self.post_multipart_form(uri, body, headers: nil, limit: 0)
        http = Http.new(uri, limit: limit, multipart: true)
        form_data = format_form_data(body)
        request = manual_multipart_post(uri, form_data, headers)
        http.set_form_data(form_data)
        http.send(request)
    end

    def self.manual_multipart_post(uri, form_data, headers)
        uri = URI(uri)
        text_form_data = form_data.reject { |row| row[1].is_a?(Tempfile) || row[1].is_a?(File) }
        file_form_data = form_data.select { |row| row[1].is_a?(Tempfile) || row[1].is_a?(File) }

        # Generate boundary
        boundary = "----formdata-#{rand(1000000)}"

        # Build multipart body with raw binary data
        body_parts = []

        # Add text fields
        text_form_data.each do |row|
            body_parts << "--#{boundary}\r\n"
            body_parts << "Content-Disposition: form-data; name=\"#{row[0]}\"\r\n"
            body_parts << "\r\n"
            body_parts << "#{row[1]}\r\n"
        end

        file_form_data.each do |row|
            # Add file with raw binary content
            file_content = row[1].read
            body_parts << "--#{boundary}\r\n"
            body_parts << "Content-Disposition: form-data; name=\"#{row[0]}\"; filename=\"#{row[2][:filename]}\"\r\n"
            body_parts << "Content-Type: #{row[2][:content_type]}\r\n"
            body_parts << "\r\n"
            body_parts << file_content
        end

        # Join text parts as string, then add binary content separately
        text_body = body_parts.join('')

        # Construct final body: text + binary + closing boundary
        final_body = text_body.b # Convert to binary string
        final_body << "\r\n--#{boundary}--\r\n".b

        # Create request
        request = Net::HTTP::Post.new(uri)
        headers&.each { |k, v| request[k] = v }
        request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
        request.body = final_body

        SimpleRequest.new(request)
    end

    def self.format_form_data(form_data)
        result = []
        form_data.map do |k, v|
            if k == :files && v.is_a?(Array)
                v.map.with_index do |file, index|
                    result << [
                        "files[#{index}]",
                        file['file'],
                        { filename: file['name'], content_type: file['content_type'] }
                    ]
                end
            elsif v.respond_to?(:path) && v.respond_to?(:read)
                result << [k.to_s, v]
            else
                result << [k.to_s, v.to_s]
            end
        end
        result
    end

    def self.post_url_form(uri, body, headers: nil, limit: 5)
        http = Http.new(uri, limit: limit)
        request = PostForm.new(uri, body, headers)
        http.send(request)
    end

    def self.put(uri, body, headers: nil, limit: 5)
        http = Http.new(uri, limit: limit)
        request = Put.new(uri, body, headers)
        http.send(request)
    end

    def self.put_file(uri, path, headers: nil, limit: 5, content_type: nil)
        http = Http.new(uri, limit: limit)
        response = nil
        if path.instance_of?(Tempfile)
            request = PutFile.new(uri, path.path, headers, content_type: content_type)
            response = http.send(request)
            path.close
            path.unlink
        else
            request = PutFile.new(uri, path, headers, content_type: content_type)
            response = http.send(request)
        end
        response
    end

    def self.patch(uri, body, headers: nil, limit: 5)
        http = Http.new(uri, limit: limit)
        request = Patch.new(uri, body, headers)
        http.send(request)
    end
end
