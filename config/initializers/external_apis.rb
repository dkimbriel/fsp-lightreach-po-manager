# Load external API libraries (in dependency order)
require Rails.root.join('lib/external/http_verb.rb')
require Rails.root.join('lib/external/netsuite_api.rb')
require Rails.root.join('lib/external/project_sunrise_api.rb')
require Rails.root.join('lib/external/skedulo_query.rb')
require Rails.root.join('lib/external/skedulo_api.rb')
require Rails.root.join('lib/external/lightreach.rb')
require Rails.root.join('lib/external/distribution_list.rb')

# Note: elastic_search_sunrise.rb not loaded - requires elasticsearch gem which we don't need for this app

# Initialize API clients with credentials when needed
# Note: Actual credentials should be set in config/credentials.yml.enc
