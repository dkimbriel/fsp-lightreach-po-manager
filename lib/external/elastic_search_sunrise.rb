class ElasticSearchSunrise
    require 'elasticsearch'
    require 'faraday_middleware'
    require 'faraday_middleware/aws_sigv4'
    require 'data_formatter'
    include DataFormatter

    # @@url = Rails.application.credentials.elastic_search_url_dev
    # @@url = Rails.application.credentials.elastic_search_url if Rails.env.production?
    @@url = Rails.application.credentials.elastic_search_url
    @@residential = 'BhpMj'
    @@commercial = '0pWHu'
    @@service = 'LGipM'

    @@organization_id = Rails.application.credentials.PROJECT_SUNRISE[:ORG_ID]

    @@config = {
        url: @@url,
        retry_on_failure: 0,
        request_timeout: 30,
        log: false,
        port: 443,
        transport_options: {
            request: { timeout: 30 }
        }
    }

    # Custom sort methods
    @@sort_id_desc = {
        _script: {
            type: 'number',
            script: {
                lang: 'painless',
                source: '' + "
                    def id_array = doc['_id'].value.splitOnToken('-');
                    def last_el = id_array[id_array.length - 1];
                    Integer.parseInt(last_el);
                " + ''
            },
            order: 'desc'
        }
    }

    @@sort_project_id_desc = {
        _script: {
            type: 'number',
            script: {
                lang: 'painless',
                source: '' + "
                    def id_array = doc['project_id'].value.splitOnToken('-');
                    def last_el = id_array[id_array.length - 1];
                    Integer.parseInt(last_el);
                " + ''
            },
            order: 'desc'
        }
    }

    attr_accessor :client

    def initialize(worker: nil)
        # Create credentials at runtime to ensure Rails credentials are loaded
        credentials = Aws::Credentials.new(
            Rails.application.credentials.aws_key_id,
            Rails.application.credentials.aws_secret_key
        )

        @client = Elasticsearch::Client.new(@@config) do |f|
            f.request :aws_sigv4,
                      service_name: 'es',
                      service: 'es',
                      region: 'us-west-2',
                      credentials: credentials
        end
    end

    # Department literal methods
    def residential
        @@residential
    end

    def commercial
        @@commercial
    end

    def service
        @@service
    end

    def organization_id
        @@organization_id
    end

    # Sort methods
    def self.sort_id_desc
        @@sort_id_desc
    end

    def self.sort_project_id_desc
        @@sort_project_id_desc
    end

    def get_user(email)
        query = {
            query: {
                term: { email: }
            }
        }
        search('user', query).dig('hits', 'hits', 0, '_source')
    end

    def get_user_by_id(id)
        query = {
            query: {
                ids: {
                    values: [id]
                }
            }
        }
        search('user', query).dig('hits', 'hits', 0, '_source')
    end

    def get_all_users
        query = {
            query: { match_all: {} }
        }
        scroll_search('user', query)
    end

    def find(document, id)
        query = {
            'query' => {
                'ids' => {
                    'values' => [id]
                }
            }
        }
        search(document, query)['hits']['hits'][0]
    end

    def search(index, body)
        @client.search(
            index:,
            body:
        )
    end

    def scroll_search(index, body, size = 200, limit: nil)
        result = []
        response = @client.search(
            index:,
            body:,
            scroll: '15s',
            size:
        )

        loop do
            hits = response.dig('hits', 'hits')
            break if hits.empty?
            break if limit && result.length >= limit

            hits.each do |hit|
                result.push hit
            end

            response = @client.scroll(
                body: { scroll_id: response['_scroll_id'] },
                scroll: '15s'
            )
        end

        result
    end

    def regions
        query = { query: { match_all: {} }, size: 1000 }
        results = scroll_search('region', query)
        hash = {}
        results.each do |region|
            hash[region['_id']] = region['_source']['name']
        end
        hash
    end

    def update(id:, index:, body:)
        @client.update(id:, index:, body: { doc: body })
    end

    def bulk_update(updates)
        @client.bulk(body: updates)
    end

    def delete(index, id)
        if id == 'PtpDInUBfHoNqsldq2hi'
            puts "Fuck you dude you can't do that"
        else
            @client.delete(index:, id:)
        end
    end

    def check_for_record(index:, source:)
        query = {
            query: {
                bool: {
                    must: []
                }
            }
        }
        source.each do |key, value|
            term = { term: { key => value } }
            query[:query][:bool][:must].push(term)
        end
        record = search(index, query)['hits']['hits'].first
        record['_id'] if record
    end

    def get_tag_id(tag_name)
        query = { query: { term: { name: tag_name } } }
        search('tag', query).dig('hits', 'hits', 0, '_id')
    end

    def get_task_template_by_name(name, department_id: @@residential)
        query = {
            query: {
                bool: {
                    must: [
                        { term: { 'name' => name } },
                        { term: { department_id: } }
                    ]
                }
            }
        }
        response = search('task_template', query)
        response.dig('hits', 'hits', 0)
    end

    def get_task(project_id, task_name)
        query = {
            query: {
                bool: {
                    must: [
                        {
                            term: {
                                'name.raw' => task_name
                            }
                        },
                        {
                            term: {
                                project_id:
                            }
                        }
                    ]
                }
            }
        }
        search('task', query)['hits']['hits']
    end

    def get_task_id(project_id, task_name)
        get_task(project_id, task_name).dig(0, '_id')
    end

    def get_project(project_id)
        query = {
            query: {
                term: { _id: project_id }
            }
        }
        search('project', query)['hits']['hits'][0]
    end

    def get_task_template(name, department_id: @@residential)
        query = {
            query: {
                bool: {
                    must: [
                        {
                            term: {
                                name:
                            }
                        },
                        {
                            term: {
                                department_id:
                            }
                        }
                    ]
                }
            }
        }
        search('task_template', query).dig('hits', 'hits', 0)
    end

    def get_task_template_by_id(id, department_id: 'BhpMj')
        query = {
            query: {
                bool: {
                    must: [
                        { term: { _id: id } },
                        { term: { department_id: } }
                    ]
                }
            }
        }
        search('task_template', query).dig('hits', 'hits', 0)
    end

    def get_task_template_id(name, department_id: @@residential)
        query = {
            query: {
                bool: {
                    must: [
                        {
                            term: {
                                name:
                            }
                        },
                        {
                            term: {
                                department_id:
                            }
                        }
                    ]
                }
            }
        }
        search('task_template', query).dig('hits', 'hits', 0, '_id')
    end

    def get_tasks(project_id_array, task_name, department_id: @@residential, source: %i[project_id name])
        query = {
            query: {
                bool: {
                    must: [
                        {
                            terms: {
                                'project_id' => project_id_array
                            }
                        },
                        {
                            term: {
                                'name.raw' => task_name
                            }
                        },
                        { term: { department_id: } }
                    ]
                }
            },
            _source: source
        }

        scroll_search('task', query, 1000)
    end

    def get_all_tasks(
        task_name,
        project_id_array: nil,
        department_id: @@residential,
        return_project_ids: false,
        source: nil
    )
        query = {
            query: {
                bool: {
                    must: [
                        { term: { 'name.raw' => task_name } },
                        { term: { department_id: } }
                    ]
                }
            },
            sort: @@sort_project_id_desc,
            size: 1000
        }
        query[:_source] = source if source

        if project_id_array
            project_id_filter = { terms: { project_id: project_id_array } }
            query[:query][:bool][:must].push(project_id_filter)
        end

        tasks = scroll_search('task', query, 200)

        if return_project_ids
            tasks.map { |task| task['_source']['project_id'] }
        else
            tasks
        end
    end

    def get_incomplete_tasks(
        task_name, project_id_array: nil, department_id: @@residential, return_project_ids: false,
        source: nil
    )
        source = %i[project_id] if return_project_ids
        query = {
            query: {
                bool: {
                    must: [
                        { term: { 'name.raw' => task_name } },
                        { term: { department_id: } }
                    ],
                    must_not: [
                        { term: { is_complete: true } },
                        { term: { on_hold: true } },
                        { term: { deleted: true } }
                    ]
                }
            },
            sort: @@sort_project_id_desc,
            size: 1000
        }
        query[:_source] = source if source

        if project_id_array
            project_id_filter = { terms: { project_id: project_id_array } }
            query[:query][:bool][:must].push(project_id_filter)
        end

        tasks = scroll_search('task', query, 1000)

        if return_project_ids
            tasks.map { |task| task['_source']['project_id'] }
        else
            tasks
        end
    end

    def get_complete_tasks(
        task_name,
        project_id_array: nil,
        return_project_ids: false,
        department_id: @@residential,
        source: nil,
        no_scroll: false,
        additional_term: nil,
        min_completed_at: nil
    )
        source = %i[project_id] if return_project_ids
        query = {
            query: {
                bool: {
                    must: [
                        { term: { 'name.raw' => task_name } },
                        { term: { is_complete: true } },
                        { term: { department_id: } }
                    ]
                }
            },
            sort: @@sort_project_id_desc,
            size: 1000
        }

        query[:query][:bool][:must].push(additional_term) if additional_term
        query[:_source] = source if source

        if min_completed_at
            min_completed_at_filter = { range: { completed_at: { gte: min_completed_at } } }
            query[:query][:bool][:must].push(min_completed_at_filter)
        end

        if project_id_array
            project_id_filter = { terms: { project_id: project_id_array } }
            query[:query][:bool][:must].push(project_id_filter)
        end

        tasks = no_scroll ? search('task', query).dig('hits', 'hits') : scroll_search('task', query, 1000)

        if return_project_ids
            tasks.map { |task| task['_source']['project_id'] }
        else
            tasks
        end
    end

    def get_ready_tasks(task_name, return_project_ids: false, source: nil, project_id_array: nil, department_id: nil)
        source = %i[project_id] if return_project_ids
        query = {
            query: {
                bool: {
                    must: [
                        { term: { 'name.raw' => task_name } },
                        { term: { is_ready: true } },
                        { term: { is_complete: false } },
                        { term: { on_hold: false } },
                        { term: { department_id: department_id || @@residential } }
                    ],
                    must_not: [
                        { term: { deleted: true } }
                    ]
                }
            },
            sort: [{ ready_at: 'asc' }]
        }
        query[:_source] = source if source
        query[:query][:bool][:must].push({ terms: { project_id: project_id_array } }) if project_id_array
        tasks = scroll_search('task', query, 1000)

        if return_project_ids
            tasks.map { |task| task['_source']['project_id'] }
        else
            tasks
        end
    end

    def get_blocked_tasks(task_name, source: nil, return_project_ids: false, department_id: @@residential)
        source = %i[project_id] if return_project_ids
        query = {
            query: {
                bool: {
                    must: [
                        { term: { 'name.raw' => task_name } },
                        { term: { is_ready: false } },
                        { term: { is_complete: false } },
                        { term: { on_hold: false } },
                        { term: { department_id: } }
                    ]
                }
            }
        }
        query[:_source] = source if source
        query[:_source] = ['project_id'] if return_project_ids

        if return_project_ids
            scroll_search('task', query, 1000).map { |task| task['_source']['project_id'] }
        else
            scroll_search('task', query, 1000)
        end
    end

    def assign_task_to_user(task_id, user_id)
        body = {
            'script' => {
                'source' => 'ctx._source.user_id = params.user_id',
                'params' => {
                    'user_id' => user_id
                }
            }
        }
        @client.update(id: task_id, index: 'task', body:)
    end

    def get_project_tasks(project_id)
        query = {
            query: {
                term: { project_id: }
            },
            size: 1000
        }
        search('task', query).dig('hits', 'hits')
    end

    def get_projects(project_id_array, property_array, contact_property_array: nil)
        query = {
            query: { match_all: {} },
            sort: @@sort_id_desc
        }

        query[:query] = { terms: { '_id' => project_id_array } } if project_id_array

        projects = scroll_search('project', query, 1000)
        mappings = get_field_mappings(property_array)
        contact_mappings = []

        contacts = []
        if contact_property_array.present?
            customer_id_array = projects.map { |project| project['_source']['primary_customer_id'] }
            contacts = get_customers(customer_id_array)
            contact_mappings = get_contact_field_mappings(contact_property_array)
        end

        projects.map do |project|
            result = {
                id: project['_id'],
                banner: project['_source']['banner'],
                created_at: project['_source']['created_at'],
                critical_path_stage: project.dig('_source', 'critical_path', 'stage_name'),
                deal_id: project['_source']['object_id'] || project['_source']['deal_id'],
                fsp_properties: project['_source']['fsp_properties'],
                name: project['_source']['name'],
                object_id: project['_source']['object_id'],
                on_hold: project['_source']['on_hold'],
                primary_customer_id: project['_source']['primary_customer_id'],
                region_id: project['_source']['region_id'],
                tag_ids: project['_source']['tag_ids']
            }

            mappings.map do |name, field_id|
                fields = project['_source']['fields']
                value = (fields.detect { |field| field['id'] == field_id } || { 'text' => '' })['text']
                result[name] = value
                Time.at(value.to_i / 1000).strftime('%F') if name == 'closedate'
            end

            contact = contacts.detect { |contact| contact['_source']['project_id'].include?(project['_id']) }
            contact_mappings.map do |name, field_id|
                next unless contact.present?

                fields = contact['_source']['fields']
                value = (fields.detect { |field| field['id'] == field_id } || { 'text' => '' })['text']
                result[name] = value
            end

            result
        end
    end

    def get_customers(customer_id_array, source: nil)
        query = {
            query: {
                bool: {
                    must: [
                        { terms: { _id: customer_id_array } }
                    ]
                }
            },
            size: 1000
        }
        query[:_source] = source unless source.nil?
        scroll_search('customer', query, 1000)
    end

    def get_files_by_category(project_id, category_id)
        query = {
            query: {
                bool: {
                    must: [
                        { term: { project_id: } },
                        { term: { category_id: } }
                    ]
                }
            },
            size: 1000
        }
        scroll_search('file', query, 1000)
    end

    def get_pulse_comments_for_project(project_id)
        query = {
            query: {
                term: { 'project_id' => project_id }
            }
        }
        scroll_search('pulse', query, 1000)
    end

    def get_pulse_comments_for_projects(project_ids)
        query = {
            query: {
                terms: { 'project_id' => project_ids }
            },
            _source: %w[project_id created_at metadata.task_id]
        }
        scroll_search('pulse', query, 10_000)
    end

    def get_pulse_comments_for_task(task_id)
        query = {
            query: {
                term: { 'metadata.task_id' => task_id }
            }
        }
        scroll_search('pulse', query, 1000)
    end

    def get_last_comment(project_id, task_name: nil)
        task_id = task_name ? get_task_id(project_id, task_name) : nil
        must = []
        must << { term: { project_id: } }
        must << { term: { 'metadata.task_id' => task_id } } if task_id
        query = {
            query: { bool: { must: } },
            sort: [{ created_at: 'desc' }]
        }

        comment = search('pulse', query)['hits']['hits'][0]
        if comment.present?
            body = comment['_source']['body']
            ActionController::Base.helpers.strip_tags(body)
        else
            ''
        end
    end

    def get_last_pulse_comment(project_id)
        query = {
            query: {
                term: { _id: project_id }
            },
            sort: [{ created_at: 'desc' }],
            size: 1,
            _source: ['last_pulse_data']
        }
        project = search('project', query).dig('hits', 'hits', 0)
        return '' unless project

        body = project.dig('_source', 'last_pulse_data', 'body')
        user_name = project.dig('_source', 'last_pulse_data', 'user_name')
        created_at = project.dig('_source', 'last_pulse_data', 'created_at')

        return '' if body.blank? || user_name.blank? || created_at.nil?

        created_at_string = Time.at(created_at / 1000).strftime('%m/%d/%Y %I:%M %p')
        body = ActionController::Base.helpers.strip_tags(body)

        "#{user_name} - #{created_at_string}:\n#{body}"
    end

    def get_last_comment_with_meta_data(project_id, task_name: nil)
        task_id = task_name ? get_task_id(project_id, task_name) : nil
        must = []
        must << { term: { project_id: } }
        must << { term: { 'metadata.task_id' => task_id } } if task_id
        query = {
            query: { bool: { must: } },
            sort: [{ created_at: 'desc' }]
        }

        comment = search('pulse', query)['hits']['hits'][0]
        if comment.present?
            comment
        else
            ''
        end
    end

    def update_tag(project_id, tag_id)
        body = {
            'script' => {
                'source' => 'if(! ctx._source.tag_ids.contains(params.tag)) {ctx._source.tag_ids.add(params.tag)}',
                'params' => {
                    'tag' => tag_id
                }
            }
        }
        @client.update(id: project_id, index: 'project', body:)
    end

    def critical_path(department_id: @@residential)
        critical_path_query = {
            query: {
                bool: {
                    must: [
                        { term: { organization_id: @@organization_id } },
                        { term: { department_id: } }
                    ]
                }
            }
        }
        critical_path_document = search('critical_path', critical_path_query)
        critical_path_hash = {}
        critical_path_document['hits']['hits'][0]['_source']['stages'].map.with_index do |stage, index|
            critical_path_hash[stage['id']] = { 'name' => stage['name'], 'index' => index }
        end
        critical_path_hash
    end

    def organization
        organization_query = {
            query: {
                'bool' => {
                    'must' => [
                        {
                            'term' => {
                                'organization_id' => @@organization_id
                            }
                        }
                    ]
                }
            }
        }

        organization_document = search 'organization', organization_query
        organization_document['hits']['hits'][0]
    end

    def mark_generated(project_id)
        body = {
            'script' => {
                'source' => "
                    ctx._source.is_generated = true
                "
            }
        }
        @client.update(id: project_id, index: 'project', body:)
    end

    def mark_task_on_hold(id)
        body = {
            'script' => {
                'source' => "
                    ctx._source.on_hold = true
                "
            }
        }
        @client.update(id:, index: 'task', body:)
    end

    def mark_project_on_hold(project_id)
        body = {
            'script' => {
                'source' => "
                    ctx._source.on_hold = true
                "
            }
        }
        query = {
            query: {
                term: { project_id: }
            }
        }
        @client.update(id: project_id, index: 'project', body:)
        @client.update_by_query(index: 'task', body: { query:, script: body['script'] })
    end

    def fix_dependencies(main_task_id, new_dependencies: [], remove_dependencies: nil)
        task = find('task', main_task_id)
        return unless task

        task_source = task['_source']
        project_id = task_source['project_id']
        task_dependencies = task_source['dependents'].map { |dep| dep['id'] }

        task_template_id = task_source['task_template_id']
        return nil if task_template_id.blank?

        task_template = find('task_template', task_template_id)
        return nil unless task_template

        task_template_source = task_template['_source']['dependents'] || []

        new_dependencies ||= []
        tt_dependencies = task_template_source.select { |dep| dep['is_active'] }.map { |dep| dep['id'] }
        tt_dependencies += new_dependencies
        tt_dependencies.reject! { |dependency| remove_dependencies.include?(dependency) } if remove_dependencies
        tt_dependencies.uniq!

        new_dependency_array = []
        remove_dependency_array = []
        remove_dependency_name_array = []
        dependency_statuses = []
        dependency_completed_at = []

        tt_dependencies.map do |dependency_task_template_id|
            is_complete, task_id, completed_at = check_dependency(project_id, dependency_task_template_id)
            next if task_id.blank?

            result = {
                'is_active' => true,
                'id' => task_id
            }
            dependency_statuses.push(is_complete)
            dependency_completed_at.push(completed_at)
            new_dependency_array.push(result)
        end

        task_dependencies.map do |id|
            dep_task_source = begin
                find('task', id)['_source']
            rescue StandardError
                nil
            end

            if dep_task_source
                name = dep_task_source['name']
                this_task_template_id = dep_task_source['task_template_id']
                no_longer_dependent = !tt_dependencies.include?(this_task_template_id)
                remove_dependency_array.push(id) if no_longer_dependent
                remove_dependency_name_array.push(name) if no_longer_dependent
            else
                remove_dependency_array.push(id)
                remove_dependency_name_array.push(name)
            end
        end

        dependency_completed_at.reject! { |completed_at| completed_at.nil? }
        dependency_completed_at.sort!
        ready = !dependency_statuses.include?(false)
        ready_now = ready && !task_source['ready_at']
        ready_at = dependency_completed_at[-1] || task_source['completed_at']

        params = {
            'new_dependencies' => new_dependency_array,
            'removed_dependencies' => remove_dependency_array,
            'removed_dependency_name_array' => remove_dependency_name_array,
            'ready_at' => ready_at,
            'ready' => ready,
            'ready_now' => ready_now
        }

        body = {
            'script' => {
                'source' => "
                if (ctx._source.dependents.length == 0 && ctx._source.is_ready != true) {
                    ctx._source.is_ready = true
                }

                for (int i=params.new_dependencies.length-1; i>=0; i--) {
                    if(! ctx._source.dependents.contains(params.new_dependencies[i])) {ctx._source.dependents.add(params.new_dependencies[i])}
                }

                for (int i=ctx._source.dependents.length-1; i>=0; i--) {
                    if (params.removed_dependencies.contains(ctx._source.dependents[i].id)) {ctx._source.dependents.remove(i)}
                }

                for (int i=ctx._source.dependents.length-1; i>=0; i--) {
                    if (ctx._source.dependents[i].id == '') { ctx._source.dependents.remove(i)}
                }

                if (params.ready) {
                    ctx._source.is_ready = true;
                    if(params.ready_now) {
                        ctx._source.ready_at = params.ready_at;
                    }
                }

                if (!params.ready) {
                    ctx._source.is_ready = false;
                    ctx._source.ready_at = null;
                }
                ",

                'params' => params
            }
        }

        puts "Fixing dependencies for #{project_id}: #{task_source['name']}"
        @client.update(id: main_task_id, index: 'task', body:)
    end

    def fix_required_fields(task)
        puts task['_source']['project_id']
        id = task['_id']
        task_template_id = task['_source']['task_template_id']
        task_template = find('task_template', task_template_id)
        required_fields = task_template['_source']['required_fields']
        body = {
            'script' => {
                'source' => 'ctx._source.required_fields = params.required_fields',
                'params' => { 'required_fields' => required_fields }
            }
        }
        @client.update(id:, index: 'task', body:)
    end

    def fix_required_files(task)
        puts task['_source']['project_id']
        id = task['_id']
        task_template_id = task['_source']['task_template_id']
        task_template = find('task_template', task_template_id)

        return if task_template.blank?

        required_files = task_template['_source']['required_files']
        body = {
            'script' => {
                'source' => 'ctx._source.required_files = params.required_files',
                'params' => { 'required_files' => required_files }
            }
        }
        @client.update(id:, index: 'task', body:)
    end

    def update_task_name(task, name)
        puts task['_source']['project_id']
        id = task['_id']
        body = {
            'script' => {
                'source' => 'ctx._source.name = params.name;',
                'params' => { 'name' => name }
            }
        }
        @client.update(id:, index: 'task', body:)
    end

    def update_task_notes(task, notes)
        puts task['_source']['project_id']
        id = task['_id']
        body = {
            'script' => {
                'source' => 'ctx._source.notes = params.notes;',
                'params' => { 'notes' => notes }
            }
        }
        @client.update(id:, index: 'task', body:)
    end

    def update_region(id, region)
        body = {
            'script' => {
                'source' => "
                    ctx._source.region_id = params.region
                ",
                'params' => {
                    'region' => region
                }
            }
        }
        @client.update(id:, index: 'task', body:)
    end

    def check_dependency(project_id, task_template_id)
        query = {
            'query' => {
                'bool' => {
                    'must' => [
                        {
                            'term' => {
                                'project_id' => project_id
                            }
                        },
                        {
                            'term' => {
                                'task_template_id' => task_template_id
                            }
                        }
                    ]
                }
            }
        }

        task = search('task', query).dig('hits', 'hits')[0] || {}

        id = task.dig('_id')
        is_complete = task.dig('_source', 'is_complete')
        completed_at = task.dig('_source', 'completed_at')
        [is_complete, id, completed_at]
    end

    def get_tasks_with_dependency(task_name, blocking_task_name, return_project_ids: false)
        blocking_query = {
            query: {
                bool: {
                    must: [
                        { term: { 'name.raw' => blocking_task_name } },
                        { term: { department_id: @@residential } }
                    ]
                }
            },
            _source: ['project_id']
        }
        blocking_tasks = scroll_search('task', blocking_query)
        blocking_task_ids = blocking_tasks.map { |task| task['_id'] }
        blocking_ids = blocking_tasks.map { |task| task['_source']['project_id'] }

        # Find incomplete tasks with a matching name that are not on hold
        # Limit to tasks where the blocking task also exists on that project
        # Find tasks where the blocking tasks are not listed in the dependents array
        blocked_query = {
            query: {
                bool: {
                    must: [
                        { term: { 'name.raw' => task_name } },
                        { terms: { project_id: blocking_ids } },
                        { term: { is_complete: false } },
                        {
                            nested: {
                                path: 'dependents',
                                query: {
                                    terms: {
                                        'dependents.id' => blocking_task_ids
                                    }
                                }
                            }
                        }
                    ]
                }
            }
        }
        result = scroll_search('task', blocked_query)
        if return_project_ids
            result.map { |task| task['_source']['project_id'] }
        else
            result
        end
    end

    def get_field_dictionary
        deal_mappings = organization['_source']['hubspot_mappings']['deals']
        ticket_mappings = organization['_source']['hubspot_mappings']['tickets']
        contact_mappings = organization['_source']['hubspot_mappings']['contacts']
        simple_mappings = {}

        deal_mappings.map do |k, v|
            simple_mappings[k] = v['name']
        end

        ticket_mappings.map do |k, v|
            simple_mappings[k] = v['name']
        end

        contact_mappings.map do |k, v|
            simple_mappings[k] = v['name']
        end

        simple_mappings
    end

    def get_contact_field_dictionary
        contact_mappings = organization['_source']['hubspot_mappings']['contacts']
        simple_mappings = {}

        contact_mappings.map do |k, v|
            simple_mappings[k] = v['name']
        end

        simple_mappings
    end

    def get_field_mappings(property_array, use_ticket_fields: false)
        org = organization
        deal_mappings = org['_source']['hubspot_mappings']['deals']
        deal_mappings = org['_source']['hubspot_mappings']['tickets'] if use_ticket_fields
        contact_mappings = org['_source']['hubspot_mappings']['contacts']

        simple_mappings = {}
        property_array.map do |property|
            property = property.to_s
            field_id = deal_mappings.select { |_k, v| v['name'] == property }.first[0]
            simple_mappings[property] = field_id
        rescue StandardError
            field_id = contact_mappings.select { |_k, v| v['name'] == property }.first[0]
            simple_mappings[property] = field_id
        end
        simple_mappings
    end

    def get_object_field_mappings(object, property_array)
        mappings = organization['_source']['hubspot_mappings'][object]
        simple_mappings = {}
        property_array.map do |property|
            property = property.to_s
            field_id = mappings.select { |_k, v| v['name'] == property }.first[0]
            simple_mappings[property] = field_id
        end
        simple_mappings
    end

    def get_contact_field_mappings(property_array)
        get_object_field_mappings('contacts', property_array)
    end

    def get_ticket_field_mappings(property_array)
        get_object_field_mappings('tickets', property_array)
    end

    def get_department(department_id)
        query = {
            "query": {
                'term': {
                    '_id': department_id
                }
            }
        }
        search('department', query).dig('hits', 'hits', 0)
    end

    def get_task_field_mappings(reverse: false, department_id: 'BhpMj')
        task_mappings = get_department(department_id)['_source']['task_fields']
        field_dictionary = {}
        task_mappings.map do |x|
            field_name = x['name']
            field_id = x['id']
            if reverse
                field_dictionary[field_name] = field_id
            else
                field_dictionary[field_id] = field_name
            end
        end
        field_dictionary
    end

    def update_task(task_id, body, task_field_mappings)
        id_body = {}
        body.map do |field_name, value|
            id_body[task_field_mappings[field_name]] = value
        end

        script = {
            source: "
                params.id_body.each((k, v) -> {
                    boolean keyExistsInFields = false;
                    for (int i=0; i<ctx._source.fields.length; i++) {
                        if (ctx._source.fields[i].id == k) {
                            ctx._source.fields[i].text = v;
                            keyExistsInFields = true;
                        }
                    }

                    if (!keyExistsInFields) {
                        Map newField = new HashMap();
                        newField.put('id', k);
                        newField.put('text', v);
                        ctx._source.fields.add(newField);
                    }

                    return null;
                });
            ",
            params: {
                id_body:
            }
        }

        update = {
            script:
        }

        puts @client.update(id: task_id, index: 'task', body: update)
    end

    def get_field_id(field_name)
        get_field_mappings([field_name]).values.first
    end

    def get_categories(department_id)
        query = { query: { term: { department_id: } }, size: 1000 }
        categories = scroll_search('category', query)
        result = {}
        categories.map do |category|
            result[category['_source']['name']] = category['_id']
        end
        result
    end

    def get_category_by_name(name, department_id: @@residential)
        query = { query: { bool: { must: [{ term: { name: } }, { term: { department_id: } }] } } }
        search('category', query).dig('hits', 'hits', 0)
    end

    def clean_pulse
        query = {
            size: 1000,
            query: {
                match_phrase: {
                    body: 'Ticket Description: '
                }
            }
        }
        results = scroll_search('pulse', query, 1000)
        puts results.count
        results.map do |result|
            id = result['_id']
            puts id
            delete('pulse', id)
        end
    end

    def get_pulse_comment_list(project_id, task_name: nil)
        task_id = task_name ? get_task_id(project_id, task_name) : nil
        must = []
        must << { term: { project_id: } }
        must << { term: { 'metadata.task_id' => task_id } } if task_id
        query = {
            query: { bool: { must: } },
            sort: [{ created_at: 'desc' }]
        }

        pulse_hash = search('pulse', query)['hits']['hits']
        comments = []
        pulse_hash.map do |pulse|
            body = pulse['_source']['body']
            created_at = pulse['_source']['created_at']
            comment_hash = {
                comment: ActionController::Base.helpers.strip_tags(body),
                created_at: convert_unix_to_date_str?(created_at)
            }
            comments.push(comment_hash)
        end
        comments
    end

    def get_projects_with_banner(banner_name, size: 1000)
        query = {
            query: {
                term: {
                    banner: banner_name
                }
            },
            _source: []
        }
        projects = scroll_search('project', query, size)
        projects.map { |project| project['_id'] }
    end

    def add_banner_to_project(project_id, banner_name)
        body = {
            script: {
                source: "
                    if (ctx._source.banner == null) {
                        ctx._source.banner = [];
                    }

                    if (ctx._source.banner instanceof String) {
                        ctx._source.banner = [ctx._source.banner];
                    }

                    if (!ctx._source.banner.contains(params.banner)) {
                        ctx._source.banner.add(params.banner);
                    }
                ",
                params: {
                    banner: banner_name
                }
            }
        }
        @client.update(id: project_id, index: 'project', body:)

        task_query = {
            query: { term: { project_id: project_id } },
            script: {
                source: "
                    if (ctx._source.project_banner == null) {
                        ctx._source.project_banner = [];
                    }

                    if (ctx._source.project_banner instanceof String) {
                        ctx._source.project_banner = [ctx._source.project_banner];
                    }

                    if (!ctx._source.project_banner.contains(params.banner)) {
                        ctx._source.project_banner.add(params.banner);
                    }
                ",
                params: {
                    banner: banner_name
                }
            }
        }
        begin
            @client.update_by_query(index: 'task', body: task_query, conflicts: 'proceed')
        rescue StandardError
            nil
        end
    end

    def remove_banner_from_project(project_id, banner_name)
        task_query = {
            query: { term: { project_id: project_id } },
            script: {
                source: "
                    if (ctx._source.project_banner != null && ctx._source.project_banner instanceof List) {
                        ctx._source.project_banner.removeIf(b -> b == params.banner);
                    }
                ",
                params: {
                    banner: banner_name
                }
            }
        }
        begin
            puts @client.update_by_query(index: 'task', body: task_query)
        rescue StandardError => e
            puts "Error removing banner from tasks: #{e.message}"
        end

        body = {
            script: {
                source: "
                    if (ctx._source.banner != null && ctx._source.banner instanceof List) {
                        ctx._source.banner.removeIf(b -> b == params.banner);
                    }
                ",
                params: {
                    banner: banner_name
                }
            }
        }
        @client.update(id: project_id, index: 'project', body:)
    end

    def sync_task_banners(project_id, banners)
        task_query = {
            query: { term: { project_id: } },
            script: {
                source: "
                    params.banners.each(banner -> {
                        if (ctx._source.project_banner == null) {
                            ctx._source.project_banner = [];
                        }

                        if (ctx._source.project_banner instanceof String) {
                            ctx._source.project_banner = [ctx._source.project_banner];
                        }

                        if (!ctx._source.project_banner.contains(banner)) {
                            ctx._source.project_banner.add(banner);
                        }
                        return ctx._source.project_banner;
                    });
                ",
                params: {
                    banners:
                }
            }
        }
        @client.update_by_query(index: 'task', body: task_query, conflicts: 'proceed')
    end

    def change_user_email(old_email, new_email)
        query = {
            size: 1,
            _source: [],
            query: {
                term: {
                    email: old_email
                }
            }
        }
        user_id = search('user', query)['hits']['hits'][0]['_id']
        body = {
            doc: {
                email: new_email
            }
        }
        @client.update(id: user_id, index: 'user', body:)
    end

    def populate_follower_tasks(task_id,
                                user_id: nil,
                                user_name: nil,
                                department_id: @@residential,
                                team_id: nil)
        task = find('task', task_id)
        project_id = task['_source']['project_id']
        task_template_id = task['_source']['task_template_id']
        task_template = find('task_template', task_template_id)

        followers = task_template['_source']['followers']
        followers.map do |follower|
            next unless follower['is_active']

            follower_tt_id = follower['id']
            follower_task_template = find('task_template', follower_tt_id)
            task_name = follower_task_template['_source']['name']
            puts "Creating task: #{task_name}"
            ProjectSunriseApi.create_task(
                project_id,
                task_name,
                department_id:,
                user_id:,
                team_id:,
                owner: user_name
            )
        end
        sleep(5)
        FreedomIntegrations::ProjectSunriseApi.recalculate_tasks(project_id)
    end

    def opt_user_in(user_id)
        body = {
            doc: {
                dashboardMigration: {
                    dashboard: true,
                    download: true,
                    inbox: true,
                    projectPage: true,
                    projectPipeline: true,
                    taskPipeline: true
                }
            }
        }
        @client.update(id: user_id, index: 'user', body:)
    end
end
