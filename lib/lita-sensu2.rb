require 'lita'

Lita.load_locales Dir[File.expand_path(
  File.join('..', '..', 'locales', '*.yml'), __FILE__
)]

require 'utils/sensu_http'
require 'utils/sensu'
require 'lita/handlers/sensu2'

Lita::Handlers::Sensu2.template_root File.expand_path(
  File.join('..', '..', 'templates'),
  __FILE__
)
