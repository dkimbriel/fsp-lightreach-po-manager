class SkeduloApi
    require_relative "./skedulo_query"

    @@skedulo_api_uri = URI("https://api.skedulo.com/graphql/graphql")

    def self.find_jobs(job_type, start_time:, end_time:)
        query = "query fetchJobs($filter: EQLQueryFilterJobs!, $sort: EQLOrderByClauseJobs!) {
            jobs(filter: $filter, orderBy: $sort) {
                edges {
                    node {
                        UID
                        Name
                        Description
                        ProjectSunriseID
                        JobStatus
                        Type
                        Start
                        End
                        Region{
                            Name
                        }
                    }
                }
            }
        }"

        start_time = SkeduloApi.new.format_time_to_skedulo(start_time)
        end_time = SkeduloApi.new.format_time_to_skedulo(end_time)
        filter = "Type == \"#{job_type}\" AND Start >= #{start_time} AND Start <= #{end_time}"
        filter += ' AND (JobStatus == "Dispatched" OR JobStatus == "Ready" OR JobStatus == "En Route" OR JobStatus == "On Site" OR JobStatus == "In Progress" OR JobStatus == "Complete")'

        Rails.logger.info "[SkeduloApi] Querying for #{job_type} jobs from #{start_time} to #{end_time}"
        Rails.logger.info "[SkeduloApi] Filter: #{filter}"

        variables = { "filter" => filter, "sort" => "Start ASC" }
        response_body = SkeduloQuery.send(query, variables)
        results = response_body.dig("data", "jobs", "edges") || []

        Rails.logger.info "[SkeduloApi] Found #{results.length} #{job_type} jobs"

        results
    end

    def self.get_job(uid)
        query = "query fetchJobs($filter: EQLQueryFilterJobs!, $sort: EQLOrderByClauseJobs!) {
            jobs(filter: $filter, orderBy: $sort) {
                edges {
                    node {
                    UID
                    Name
                    Description
                    JobStatus
                    Type
                    Start
                    End
                    WarmHandoffType
                    Region{
                        Timezone
                    }
                    JobAllocations{
                        Status
                        Resource{
                            Name
                            Email

                        }
                      }
                    }
                }
            }
        }"
        filter = "UID == \"#{uid}\""
        variables = { "filter" => filter, "sort" => "Start ASC" }
        response = SkeduloQuery.send(query, variables)
        response.dig("data", "jobs", "edges", 0, "node")
    end

    def self.list_jobs(start_date_time, end_date_time, region_id)
        first_query = "
        query fetchJobs($filter: EQLQueryFilterJobs!) {
            jobs(filter: $filter) {
                pageInfo {
                    hasNextPage
                    endCursor
                }
                edges {
                    node {
                        UID
                        ProjectSunriseID
                    }
                }
            }
        }
        "

        query = "
        query fetchJobs($filter: EQLQueryFilterJobs!, $cursor: Base64!) {
            jobs(after: $cursor, filter: $filter) {
                pageInfo {
                    hasNextPage
                    endCursor
                }
                edges {
                    node {
                        UID
                        ProjectSunriseID
                    }
                }
            }
        }
        "
        jobs = []
        filter = 'JobStatus == "Dispatched" OR JobStatus == "Ready" OR JobStatus == "En Route" OR JobStatus == "On Site" OR JobStatus == "In Progress" OR JobStatus == "Complete"'
        filter += " AND RegionId == \"#{region_id}\""
        filter += " AND Start >= #{start_date_time} AND Start <= #{end_date_time}"
        response = SkeduloQuery.send(first_query, { "filter" => filter })
        has_next_page = response.dig("data", "jobs", "pageInfo", "hasNextPage")
        cursor = response.dig("data", "jobs", "pageInfo", "endCursor")
        (response.dig("data", "jobs", "edges") || []).each { |node| jobs.push(node["node"]) }

        while has_next_page
            response = SkeduloQuery.send(query, { "filter" => filter, "cursor" => cursor })
            has_next_page = response.dig("data", "jobs", "pageInfo", "hasNextPage")
            cursor = response.dig("data", "jobs", "pageInfo", "endCursor")
            (response.dig("data", "jobs", "edges") || []).each { |node| jobs.push(node["node"]) }
        end
        jobs
    end

    def self.update_job(update_input)
        query = "mutation updateJob($updateInput: UpdateJobs!) {\r\n  schema {\r\n  \tupdateJobs(input: $updateInput)\r\n  }\r\n}"
        variables = { "updateInput" => update_input }

        SkeduloQuery.send(query, variables)
    end

    def self.list_jobs_for_project(project_id, type)
        query = "query fetchJobs($filter: EQLQueryFilterJobs!, $sort: EQLOrderByClauseJobs!) {
            jobs(filter: $filter, orderBy: $sort) {
                edges {
                    node {
                    UID
                    Name
                    Description
                    JobStatus
                    Type
                    Start
                    End
                    CreatedDate
                    Region{
                        Timezone
                    }
                    JobAllocations{
                        Status
                        Resource{
                            Name
                            Email

                        }
                      }
                    }
                }
            }
          }"
        filter = "ProjectSunriseID == \"#{project_id}\" AND Type == \"#{type}\" AND Start != null"
        variables = { "filter" => filter, "sort" => "Start ASC" }
        response_body = SkeduloQuery.send(query, variables)

        jobs = response_body.dig("data", "jobs", "edges") || []
        jobs.map { |job| job["node"] }
    end

    def self.list_all_jobs_for_project(project_id)
        query = "query fetchJobs($filter: EQLQueryFilterJobs!, $sort: EQLOrderByClauseJobs!, $allocationFilter: EQLQueryFilterJobAllocations!) {
            jobs(filter: $filter, orderBy: $sort) {
                edges {
                    node {
                    UID
                    Name
                    Description
                    JobStatus
                    Type
                    Start
                    End
                    CreatedDate
                    Region{
                        Timezone
                    }
                    JobAllocations(filter: $allocationFilter){
                        Status
                        Resource{
                            Name
                            Email

                        }
                      }
                    }
                }
            }
          }"
        filter = "ProjectSunriseID == \"#{project_id}\"
            AND Type != \"Phone\"
            AND Type !=  \"In Home\"
            AND Start != null
            AND (
                JobStatus == \"Dispatched\"
                OR JobStatus == \"Ready\"
                OR JobStatus == \"En Route\"
                OR JobStatus == \"On Site\"
                OR JobStatus == \"In Progress\"
                OR JobStatus == \"Complete\"
            )
        ".gsub('\r\n', " ")
        variables = { "filter" => filter, "sort" => "Start ASC", "allocationFilter" => 'Status != "Deleted"' }
        response_body = SkeduloQuery.send(query, variables)

        jobs = response_body.dig("data", "jobs", "edges") || []
        jobs.map { |job| job["node"] }
    end

    def self.find_job(project_id, type)
        query = "query fetchJobs($filter: EQLQueryFilterJobs!, $sort: EQLOrderByClauseJobs!) {
            jobs(filter: $filter, orderBy: $sort) {
                edges {
                    node {
                    UID
                    Name
                    Description
                    JobStatus
                    Type
                    Start
                    End
                    CreatedDate
                    Region{
                        Timezone
                    }
                    JobAllocations{
                        Status
                        Resource{
                            Name
                            Email

                        }
                      }
                    }
                }
            }
          }"
        filter = "ProjectSunriseID == \"#{project_id}\" AND Type == \"#{type}\" AND JobStatus != \"Cancelled\" AND JobStatus != \"Queued\" AND JobStatus != \"Pending Allocation\" AND Start != null"
        variables = { "filter" => filter, "sort" => "Start ASC" }
        response_body = SkeduloQuery.send(query, variables)

        jobs = response_body.dig("data", "jobs", "edges") || []
        job = jobs.first&.fetch("node", {}) || {}

        start_time_skedulo = job["Start"]
        end_time_skedulo = job["End"]
        final_end_time_skedulo = job["End"]
        job_allocations = job["JobAllocations"] || []
        job["ResourceEmail"] = job_allocations.reject { |ja| ja["Status"] == "Deleted" }.dig(-1, "Resource", "Email")

        if start_time_skedulo
            timezone = job["Region"]["Timezone"]
            start_time = Time.parse(start_time_skedulo).in_time_zone(timezone)
            end_time = Time.parse(end_time_skedulo).in_time_zone(timezone)

            start_date_in_zone = start_time.strftime("%A, %B #{start_time.day.ordinalize}")
            start_time_in_zone = start_time.strftime("%l:%M %p").strip

            end_date_in_zone = end_time.strftime("%A, %B #{end_time.day.ordinalize}")
            end_time_in_zone = end_time.strftime("%l:%M %p").strip

            job["StartTime"] = start_time_in_zone
            job["StartDate"] = start_date_in_zone

            job["EndTime"] = end_time_in_zone
            job["EndDate"] = end_date_in_zone
        end

        if start_time_skedulo && final_end_time_skedulo
            days = (Date.parse(final_end_time_skedulo) - Date.parse(start_time_skedulo)).to_i + 1
            unit = days == 1 ? "day" : "days"
            job["Days"] = days
            job["DaysWithUnit"] = days.to_s + unit
        end

        job
    end

    def format_time_to_skedulo(time_instance)
        time_array = time_instance.rfc3339.split(/[+-]/)
        time_array.pop
        time = time_array.join("-")
        time << ".000Z"
        time
    end
end
