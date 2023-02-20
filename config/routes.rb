Rails.application.routes.draw do # rubocop:disable Metrics/BlockLength
  # FYI: Routes declared at the top of the file will mask routes that have yet to be declared.
  # The engines are mounted last so you may override engine routes.
  concern :exportable, Blacklight::Routes::Exportable.new
  concern :searchable, Blacklight::Routes::Searchable.new
  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new

  # Note that component URLs have underscores; collections don't
  def collection_slug_constraint
    /[a-zA-Z0-9-]+/
  end

  if ENV['FINDING_AID_INGEST'] == 'true'
    resources :findingaids do
      member do
        put :reindex
      end
    end
  end

  get 'help', to: 'help#help'

  resources :repositories, only: %i[index show], controller: 'arclight/repositories' do
    member do
      get :about
    end
  end

  resource :catalog, only: [:index], as: 'catalog', path: '/catalog', controller: 'catalog' do
    concerns :searchable
    concerns :range_searchable
  end

  get '/catalog/:id/xml', action: 'ead_download', controller: 'catalog', as: 'ead_download',
                          constraints: {id: collection_slug_constraint}

  get '/catalog/:id/html', action: 'html_download', controller: 'catalog', as: 'html_download',
                           constraints: {id: collection_slug_constraint}

  get '/catalog/:id/pdf', action: 'pdf_download', controller: 'catalog', as: 'pdf_download',
                          constraints: {id: collection_slug_constraint}

  root to: "catalog#index"

  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog' do
    concerns :exportable
  end

  resources :bookmarks do
    concerns :exportable

    collection do
      delete 'clear'
    end
  end

  post '/index_finding_aids', to: 'index_finding_aids#create'

  devise_for :users

  resources :ua_record_groups, only: [:index], as: 'ua_record_groups', path: '/collections/ua-record-groups', controller: 'ua_record_groups'

  # Render a sitemap on-the-fly from a query (if configured)
  get '/custom_sitemaps/:id', controller: 'custom_sitemaps', action: 'index', defaults: {format: 'xml'},
                              constraints: ->(request) { CUSTOM_SITEMAP_CONFIG.key?(request.params[:id]) }

  mount Arclight::Engine => '/'
  mount BlacklightDynamicSitemap::Engine => '/'
  mount Blacklight::Engine => '/'
end
