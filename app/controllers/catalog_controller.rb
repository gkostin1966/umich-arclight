# frozen_string_literal: true

class CatalogController < ApplicationController
  include BlacklightRangeLimit::ControllerOverride
  include Blacklight::Catalog
  include DulArclight::Catalog

  # DUL CUSTOMIZATION: extend FieldConfigHelpers to convert
  # singular extent values e.g. "1 cubic feet"
  # include Arclight::FieldConfigHelpers
  include DulArclight::FieldConfigHelpers
  include HierarchyHelper

  # DUL CUSTOMIZATION: temporary patch for
  # ArcLight bug https://github.com/projectblacklight/arclight/issues/741
  # Patched for now by copying the raw method from Blacklight https://github.com/projectblacklight/blacklight/blob/master/app/controllers/concerns/blacklight/catalog.rb#L57-L63
  # Last checked for updates: ArcLight v0.3.2
  def raw
    raise(ActionController::RoutingError, 'Not Found') unless blacklight_config.raw_endpoint.enabled

    _, @document = search_service.fetch(params[:id])
    render json: @document
  end

  configure_blacklight do |config|
    ## Class for sending and receiving requests from a search index
    # config.repository_class = Blacklight::Solr::Repository
    #
    ## Class for converting Blacklight's url parameters to into request parameters for the search index
    # config.search_builder_class = ::SearchBuilder
    #
    ## Model that maps search index responses to the blacklight response model
    # config.response_model = Blacklight::Solr::Response

    ## Enable getting JSON at /raw endpoint
    config.raw_endpoint.enabled = true

    ## Default parameters to send to solr for all search-like requests. See also SearchBuilder#processed_parameters
    config.default_solr_params = {
      rows: 10,
      fl: '*'
    }

    # solr path which will be added to solr base url before the other solr params.
    # config.solr_path = 'select'

    # items to show per page, each number in the array represent another option to choose from.
    # config.per_page = [10,20,50,100]

    ## Default parameters to send on single-document requests to Solr. These settings are the Blacklight defaults (see SearchHelper#solr_doc_params) or
    ## parameters included in the Blacklight-jetty document requestHandler.
    #
    # config.default_document_solr_params = {
    #  qt: 'document',
    #  ## These are hard-coded in the blacklight 'document' requestHandler
    #  # fl: '*',
    #  # rows: 1,
    #  # q: '{!term f=id v=$id}'
    # }

    # DUL CUSTOMIZATION: CSV response especially for exporting
    # Bookmarks to a digitization guide.
    config.index.respond_to.csv = true

    # solr field configuration for search results/index views
    config.index.title_field = 'normalized_title_ssm'
    config.index.display_type_field = 'level_ssm'
    # config.index.thumbnail_field = 'thumbnail_path_ss'

    # solr field configuration for document/show views
    # config.show.title_field = 'title_display'
    config.show.display_type_field = 'level_ssm'
    # config.show.thumbnail_field = 'thumbnail_path_ss'

    # config.add_results_document_tool(:bookmark, partial: 'bookmark_control', if: :render_bookmarks_control?)

    config.add_results_collection_tool(:sort_widget)
    config.add_results_collection_tool(:per_page_widget)
    config.add_results_collection_tool(:view_type_group)

    # config.add_show_tools_partial(:bookmark, partial: 'bookmark_control', if: :render_bookmarks_control?)
    config.add_show_tools_partial(:email, callback: :email_action, validator: :validate_email_params)
    # DUL CUSTOMIZATION: Add CSV export especially for bookmarks
    config.add_show_tools_partial(:export_csv, partial: 'export_csv')

    # DUL Customization: Remove Some Show Tools
    # config.add_show_tools_partial(:sms, if: :render_sms_action?, callback: :sms_action, validator: :validate_sms_params)
    # config.add_show_tools_partial(:citation)

    config.add_nav_action(:bookmark, partial: 'blacklight/nav/bookmark', if: :render_bookmarks_control?)
    config.add_nav_action(:search_history, partial: 'blacklight/nav/search_history')

    # solr fields that will be treated as facets by the blacklight application
    #   The ordering of the field names is the order of the display
    #
    # Setting a limit will trigger Blacklight's 'more' facet values link.
    # * If left unset, then all facet values returned by solr will be displayed.
    # * If set to an integer, then "f.somefield.facet.limit" will be added to
    # solr request, with actual solr request being +1 your configured limit --
    # you configure the number of items you actually want _displayed_ in a page.
    # * If set to 'true', then no additional parameters will be sent to solr,
    # but any 'sniffed' request limit parameters will be used for paging, with
    # paging at requested limit -1. Can sniff from facet.limit or
    # f.specific_field.facet.limit solr request params. This 'true' config
    # can be used if you set limits in :default_solr_params, or as defaults
    # on the solr side in the request handler itself. Request handler defaults
    # sniffing requires solr requests to be made with "echoParams=all", for
    # app code to actually have it echo'd back to see it.
    #
    # :show may be set to false if you don't want the facet to be drawn in the
    # facet bar
    #
    # set :index_range to true if you want the facet pagination view to have facet prefix-based navigation
    #  (useful when user clicks "more" on a large facet and wants to navigate alphabetically across a large set of results)
    # :index_range can be an array or range of prefixes that will be used to create the navigation (note: It is case sensitive when searching values)

    config.add_facet_field 'has_online_content_ssim',
                           label: 'Online Content',
                           collapse: false,
                           query: {
                             online: { label: I18n.t('um_arclight.advanced_search.available_online'), fq: 'has_online_content_ssim:true' }
                           }
    config.add_facet_field 'repository_sim', label: 'Repository', limit: 10
    config.add_facet_field 'subarea_sim', label: 'Subarea', limit: 10
    config.add_facet_field 'collection_sim', label: 'Collection', limit: 10
    config.add_facet_field 'creator_ssim', label: 'Creator', show: false
    config.add_facet_field 'creators_ssim', label: 'Creator', limit: 10
    config.add_facet_field 'date_range_sim', label: 'Date range', range: true
    config.add_facet_field 'level_sim', label: 'Level', show: false
    config.add_facet_field 'names_ssim', label: 'Names', limit: 10
    config.add_facet_field 'places_ssim', label: 'Places', limit: 10
    config.add_facet_field 'access_subjects_ssim', label: 'Subjects', limit: 10
    config.add_facet_field 'formats_ssim', label: 'Formats', limit: 10

    # Added in ArcLight v0.4.0
    # See note in: https://github.com/projectblacklight/arclight/releases/tag/v0.4.0
    config.add_facet_field 'component_level_isim', show: false
    config.add_facet_field 'parent_ssim', show: false
    config.add_facet_field 'parent_ssi', show: false

    # # DUL CUSTOMIZATION: Add UA Record Group hierarchical facet.
    # config.add_facet_field 'ua_record_group_ssim',
    #                        limit: 99_999,
    #                        label: 'University Archives Record Group',
    #                        helper_method: :ua_record_group_display,
    #                        partial: 'blacklight/hierarchy/facet_hierarchy'

    # config.facet_display = {
    #   hierarchy: {
    #     'ua_record_group' => [['ssim'], ':']
    #   }
    # }

    # Have BL send all facet field names to Solr, which has been the default
    # previously. Simply remove these lines if you'd rather use Solr request
    # handler defaults, or have no facets.
    config.add_facet_fields_to_solr_request!

    # DUL CUSTOMIZATIONS FOR INDEX FIELDS
    # These add_index_field configs seem to only impact the data available in the search results
    # catalog.json API. They do NOT impact the presentation of search results in the UI since
    # ArcLight's templates use a custom display. We use an accessor in some cases to call methods
    # on the solr_document model to get values.
    # By default Blacklight concatenates arrays with Array#to_sentence, which we don't always want.
    # To get just a raw array, use DUL-custom helper method 'keep_raw_values'
    config.add_index_field 'normalized_title', accessor: :normalized_title, label: 'Title'
    config.add_index_field 'short_description', accessor: :short_description, label: 'Description'
    config.add_index_field 'parent_labels', accessor: :parent_labels, label: 'In', helper_method: 'keep_raw_values'
    config.add_index_field 'parent_ids', accessor: :parent_ids, label: 'Ancestor IDs', helper_method: 'keep_raw_values'
    config.add_index_field 'level', accessor: :level, label: 'Level'
    config.add_index_field 'extent', accessor: :extent, label: 'Extent'
    config.add_index_field 'containers', accessor: :containers, label: 'Containers'
    config.add_index_field 'collection_name', accessor: :collection_name, label: 'Collection'
    config.add_index_field 'eadid', accessor: :eadid, label: 'EAD ID'
    config.add_index_field 'online_content?', accessor: :online_content?, label: 'Online Content'
    config.add_index_field 'component?', accessor: :component?, label: 'Component'
    config.add_index_field 'restricted_component?', accessor: :restricted_component?, label: 'Restrictions'

    # DEBUG fields displayed in search results when debug=true is present in the request.
    config.add_index_field 'score'

    # solr fields to be displayed in the show (single result) view
    #   The ordering of the field names is the order of the display

    # "fielded" search configuration. Used by pulldown among other places.
    # For supported keys in hash, see rdoc for Blacklight::SearchFields
    #
    # Search fields will inherit the :qt solr request handler from
    # config[:default_solr_parameters], OR can specify a different one
    # with a :qt key/value. Below examples inherit, except for subject
    # that specifies the same :qt as default for our own internal
    # testing purposes.
    #
    # The :key is what will be used to identify this BL search field internally,
    # as well as in URLs -- so changing it after deployment may break bookmarked
    # urls.  A display label will be automatically calculated from the :key,
    # or can be specified manually to be different.

    # This one uses all the defaults set by the solr request handler. Which
    # solr request handler? The one set in config[:default_solr_parameters][:qt],
    # since we aren't specifying it otherwise.
    config.add_search_field 'all_fields', label: 'All Fields' do |field|
      field.include_in_simple_select = true
    end

    config.add_search_field 'within_collection' do |field|
      field.include_in_simple_select = false
      field.solr_parameters = {
        fq: '-level_sim:Collection'
      }
    end

    # Field-based searches. We have registered handlers in the Solr configuration
    # so we have Blacklight use the `qt` parameter to invoke them
    config.add_search_field 'keyword', label: 'Keyword' do |field|
      field.qt = 'search' # default
    end
    config.add_search_field 'name', label: 'Name' do |field|
      field.qt = 'search'
      field.solr_parameters = {
        qf: '${qf_name}',
        pf: '${pf_name}'
      }
    end
    config.add_search_field 'place', label: 'Place' do |field|
      field.qt = 'search'
      field.solr_parameters = {
        qf: '${qf_place}',
        pf: '${pf_place}'
      }
    end
    config.add_search_field 'subject', label: 'Subject' do |field|
      field.qt = 'search'
      field.solr_parameters = {
        qf: '${qf_subject}',
        pf: '${pf_subject}'
      }
    end

    config.add_search_field 'format', label: 'Format' do |field|
      field.qt = 'search'
      field.solr_parameters = {
        qf: '${qf_format}',
        pf: '${pf_format}'
      }
    end

    config.add_search_field 'container', label: 'Container' do |field|
      field.qt = 'search'
      field.solr_parameters = {
        qf: '${qf_container}',
        pf: '${pf_container}'
      }
    end

    config.add_search_field 'title', label: 'Title' do |field|
      field.qt = 'search'
      field.solr_parameters = {
        qf: '${qf_title}',
        pf: '${pf_title}'
      }
    end

    config.add_search_field 'identifier', label: 'Identifier' do |field|
      field.qt = 'search'
      field.solr_parameters = {
        qf: '${qf_identifier}',
        pf: '${pf_identifier}'
      }
    end

    # "sort results by" select (pulldown)
    # label in pulldown is followed by the name of the SOLR field to sort by and
    # whether the sort is ascending or descending (it must be asc or desc
    # except in the relevancy case).

    # DUL CUSTOMIZATION: relevance tiebreaker uses component order (sort_ii)
    # instead of title ABC.
    config.add_sort_field 'score desc, sort_ii asc, title_sort asc', label: 'relevance'
    config.add_sort_field 'date_sort asc', label: 'date (ascending)'
    config.add_sort_field 'date_sort desc', label: 'date (descending)'
    config.add_sort_field 'creator_sort asc', label: 'creator (A-Z)'
    config.add_sort_field 'creator_sort desc', label: 'creator (Z-A)'
    config.add_sort_field 'title_sort asc', label: 'title (A-Z)'
    config.add_sort_field 'title_sort desc', label: 'title (Z-A)'

    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 5

    # Configuration for autocomplete suggestor
    config.autocomplete_enabled = false # autocomplete_disabled DCP2-474: ArcLight - Bug: Titles in italics are cut off
    config.autocomplete_path = 'suggest'

    ##
    # Arclight Configurations

    config.show.document_presenter_class = DulArclight::ShowPresenter
    config.index.document_presenter_class = Arclight::IndexPresenter

    ##
    # Configuration for partials
    config.index.partials = %i[arclight_index_default]

    ##
    # Configuration for index actions
    config.index.document_actions << :containers
    config.index.document_actions << :restricted_component_badge
    config.index.document_actions << :online_content_label
    # config.add_results_document_tool :arclight_bookmark_control, partial: 'arclight_bookmark_control'
    config.index.document_actions.delete(:bookmark)

    # NOTE cannot add using_field here since it is to appear at the bottom
    # of the collection show page after other elements that are not part
    # of the metadata_partials config.
    config.show.metadata_partials_top = %i[
      summary_field
      background_field
    ]

    config.show.metadata_partials_bottom = %i[
      related_field
      indexed_terms_field
      indexes_field
    ]

    config.show.context_access_tab_items = %i[
      terms_field
      in_person_field
      contact_field
      cite_field
    ]

    config.show.component_metadata_partials = %i[
      component_field
      component_indexed_terms_field
      component_indexes_field
    ]

    config.show.component_access_tab_items = %i[
      component_terms_field
      in_person_field
      contact_field
      cite_field
    ]

    # ===========================
    # COLLECTION SHOW PAGE FIELDS
    # ===========================

    # Collection Show Page - Summary Section
    config.add_summary_field 'creators_ssim', label: 'Creator', link_to_facet: true
    config.add_summary_field 'abstract_tesim', label: 'Abstract', helper_method: :render_html_tags

    # DUL CUSTOMIZATION: singularize extent
    config.add_summary_field 'physdesc_tesim', label: 'Extent', helper_method: :singularize_extent,
                                               separator_options: {
                                                 words_connector: '<br/>',
                                                 two_words_connector: '<br/>',
                                                 last_word_connector: '<br/>'
                                               }

    config.add_summary_field 'languages', label: 'Language', accessor: 'languages', separator_options: {
                                                                                      words_connector: '<br/>',
                                                                                      two_words_connector: '<br/>',
                                                                                      last_word_connector: '<br/>'
                                                                                    },
                                          if: lambda { |_context, _field_config, document|
                                                document.languages.present?
                                              }

    config.add_summary_field 'collection_unitid_ssm', label: 'Call Number', accessor: :collection_unitid,
                                                      if: lambda { |_context, _field_config, document|
                                                            /^\s*bhl\s*$/i.match?(document.repository_id)
                                                          }

    config.add_summary_field 'ua_record_group_ssim', label: 'University Archives Record Group',
                                                     helper_method: :link_to_ua_record_group_facet, separator_options: {
                                                       words_connector: '<br/>',
                                                       two_words_connector: '<br/>',
                                                       last_word_connector: '<br/>'
                                                     }

    # Collection Show Page - Top Restrictions Snippet Section
    config.add_restrictions_field 'accessrestrict_tesim', label: 'Restrictions', helper_method: :render_html_tags
    config.add_restrictions_field 'phystech_tesim', label: 'Physical / Technical Access Restrictions', helper_method: :render_html_tags
    config.add_restrictions_field 'userestrict_tesim', label: 'Use & Permissions', helper_method: :convert_rights_urls

    # Collection Show Page - Background Section
    config.add_background_field 'para_tesim', label: '', helper_method: :render_html_tags
    config.add_background_field 'scopecontent_tesim', label: 'Scope and Content', helper_method: :render_html_tags
    config.add_background_field 'bioghist_tesim', label: 'Biographical / Historical', helper_method: :render_bioghist
    config.add_background_field 'acqinfo_ssim', label: 'Acquisition Information', helper_method: :render_html_tags
    config.add_background_field 'appraisal_tesim', label: 'Appraisal Information', helper_method: :render_html_tags
    config.add_background_field 'custodhist_tesim', label: 'Custodial History', helper_method: :render_html_tags
    config.add_background_field 'processinfo_tesim', label: 'Processing information', helper_method: :render_html_tags
    config.add_background_field 'arrangement_tesim', label: 'Arrangement', helper_method: :render_html_tags
    config.add_background_field 'fileplan_tesim', label: 'File Plan', helper_method: :render_html_tags
    config.add_background_field 'accruals_tesim', label: 'Accruals', helper_method: :render_html_tags
    config.add_background_field 'physloc_tesim', label: 'Physical Location', helper_method: :render_html_tags
    config.add_background_field 'materialspec_tesim', label: 'Material Specific Details', helper_method: :render_html_tags
    config.add_background_field 'odd_tesim', label: 'Other Descriptive Data', helper_method: :render_html_tags
    config.add_background_field 'descrules_ssm', label: 'Rules or Conventions', helper_method: :render_html_tags

    # Collection Show Page - Related Section
    config.add_related_field 'add_tesim', label: 'Additional Descriptive Data', helper_method: :render_html_tags
    config.add_related_field 'relatedmaterial_tesim', label: 'Related Material', helper_method: :render_html_tags
    config.add_related_field 'separatedmaterial_tesim', label: 'Separated Material', helper_method: :render_html_tags
    config.add_related_field 'otherfindaid_tesim', label: 'Other Finding Aids', helper_method: :render_html_tags
    config.add_related_field 'altformavail_tesim', label: 'Alternative Form Available', helper_method: :render_html_tags
    config.add_related_field 'originalsloc_tesim', label: 'Location of Originals', helper_method: :render_html_tags
    config.add_related_field 'bibliography_tesim', label: 'Bibliography', helper_method: :render_html_tags
    config.add_related_field 'chronlist_tesim', label: 'Chronlist', helper_method: :render_html_tags
    config.add_related_field 'index_tesim', label: 'Index', helper_method: :render_html_tags
    config.add_related_field 'list_tesim', label: 'List', helper_method: :render_html_tags

    # Collection Show Page - Indexed Terms Section
    config.add_indexed_terms_field 'access_subjects_ssim', label: 'Subjects', link_to_facet: true, separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }

    config.add_indexed_terms_field 'formats_ssim', label: 'Formats', link_to_facet: true, separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }

    config.add_indexed_terms_field 'names_coll_ssim', label: 'Names', separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }, helper_method: :link_to_name_facet

    config.add_indexed_terms_field 'places_ssim', label: 'Places', link_to_facet: true, separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }

    # Collection Show Page - Indexes Section
    config.add_indexes_field 'indexes_tesim', label: 'Other Indexes to the Collection', helper_method: :render_html_tags

    # ==========================
    # COMPONENT SHOW PAGE FIELDS
    # ==========================

    # Restrictions Displayed in a Warning Box
    config.add_component_restrictions_field 'accessrestrict_tesim', label: 'Restrictions', helper_method: :render_html_tags
    config.add_component_restrictions_field 'phystech_tesim', label: 'Physical / Technical Access - Restrictions', helper_method: :render_html_tags
    config.add_component_restrictions_field 'userestrict_tesim', label: 'Use & Permissions', helper_method: :convert_rights_urls

    # Component Show Page - Metadata Section

    # DUL CUSTOMIZATION: add creators field; it's missing in ArcLight core.
    config.add_component_field 'creators_ssim', label: 'Creator', link_to_facet: true, ignore_interesting: true
    config.add_component_field 'containers', label: 'Containers', accessor: 'containers', separator_options: {
      words_connector: ', ',
      two_words_connector: ', ',
      last_word_connector: ', '
    }, if: lambda { |_context, _field_config, document|
      document.containers.present?
    }, ignore_interesting: true
    config.add_component_field 'abstract_tesim', label: 'Abstract', helper_method: :render_html_tags

    # DUL CUSTOMIZATION: Present all physdesc as extent
    config.add_component_field 'physdesc_tesim', label: 'Extent', helper_method: :singularize_extent,
                                                 separator_options: {
                                                   words_connector: '<br/>',
                                                   two_words_connector: '<br/>',
                                                   last_word_connector: '<br/>'
                                                 },
                                                 ignore_interesting: true

    config.add_component_field 'scopecontent_tesim', label: 'Scope and Content', helper_method: :render_html_tags
    config.add_component_field 'acqinfo_ssim', label: 'Acquisition Information', helper_method: :render_html_tags
    config.add_component_field 'appraisal_tesim', label: 'Appraisal Information', helper_method: :render_html_tags
    config.add_component_field 'custodhist_tesim', label: 'Custodial History', helper_method: :render_html_tags
    config.add_component_field 'processinfo_tesim', label: 'Processing Information', helper_method: :render_html_tags
    config.add_component_field 'arrangement_tesim', label: 'Arrangement', helper_method: :render_html_tags
    config.add_component_field 'fileplan_tesim', label: 'File Plan', helper_method: :render_html_tags
    config.add_component_field 'accruals_tesim', label: 'Accruals', helper_method: :render_html_tags
    config.add_component_field 'physloc_tesim', label: 'Physical Location', helper_method: :render_html_tags
    config.add_component_field 'materialspec_tesim', label: 'Material Specific Details', helper_method: :render_html_tags
    config.add_component_field 'note_tesim', label: 'Note', helper_method: :render_html_tags
    config.add_component_field 'odd_tesim', label: 'Other Descriptive Data', helper_method: :render_html_tags
    config.add_component_field 'unitid_ssm', label: 'Unit ID', helper_method: :render_html_tags

    config.add_component_field 'languages', label: 'Language', accessor: 'languages', separator_options: {
                                                                                        words_connector: '<br/>',
                                                                                        two_words_connector: '<br/>',
                                                                                        last_word_connector: '<br/>'
                                                                                      },
                                            if: lambda { |_context, _field_config, document|
                                                  document.languages.present?
                                                }

    # Component Show Page - Indexed Terms Section
    config.add_component_indexed_terms_field 'access_subjects_ssim', label: 'Subjects', link_to_facet: true, separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }

    config.add_component_indexed_terms_field 'formats_ssim', label: 'Formats', link_to_facet: true, separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }

    config.add_component_indexed_terms_field 'names_ssim', label: 'Names', separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }, helper_method: :link_to_name_facet

    config.add_component_indexed_terms_field 'places_ssim', label: 'Places', link_to_facet: true, separator_options: {
      words_connector: '<br/>',
      two_words_connector: '<br/>',
      last_word_connector: '<br/>'
    }

    # Component Show Page - Indexes Section
    config.add_component_indexes_field 'indexes_tesim', label: 'Other Indexes', helper_method: :render_html_tags

    # =================
    # ACCESS TAB FIELDS
    # =================

    # Collection Show Page Access Tab - Terms and Conditions Section
    config.add_terms_field 'accessrestrict_tesim', label: 'Restrictions', helper_method: :render_html_tags
    config.add_terms_field 'phystech_tesim', label: 'Physical / Technical Access - Restrictions', helper_method: :render_html_tags
    config.add_terms_field 'userestrict_tesim', label: 'Use & Permissions', helper_method: :convert_rights_urls

    # Component Show Page Access Tab - Terms and Conditions Section
    config.add_component_terms_field 'parent_access_restrict_tesim', label: 'Restrictions', helper_method: :render_html_tags
    config.add_component_terms_field 'parent_access_phystech_tesim', label: 'Physical / Technical Access - Restrictions', helper_method: :render_html_tags
    config.add_component_terms_field 'parent_access_terms_tesim', label: 'Use & Permissions', helper_method: :convert_rights_urls

    # Collection and Component Show Page Access Tab - In Person Section
    config.add_in_person_field 'repository_ssm', if: :repository_config_present, label: 'Location of This Collection',
                                                 helper_method: :context_access_tab_repository
    config.add_in_person_field 'id', if: :before_you_visit_note_present, label: 'Before you visit',
                                     helper_method: :context_access_tab_visit_note # Using ID because we know it will always exist

    # Collection and Component Show Page Access Tab - Contact Section
    config.add_contact_field 'repository_ssm', if: :repository_config_present, label: 'Contact', helper_method: :access_repository_contact

    # Collection and Component Show Page Access Tab - How to Cite Section
    config.add_cite_field 'prefercite_tesim', label: 'Preferred Citation', helper_method: :render_html_tags
    config.add_cite_field 'permalink_ssi', label: 'Permalink', helper_method: :render_links

    # DUL CUSTOMIZATION: turn bookmark controls back on
    # Remove unused show document actions
    # %i[citation email sms].each do |action|
    #   config.view_config(:show).document_actions.delete(action)
    # end

    # Insert the breadcrumbs at the beginning
    # config.show.partials.unshift(:show_upper_metadata)
    # config.show.partials.unshift(:show_breadcrumbs)
    config.show.partials.delete(:show_header)

    ##
    # Online Contents Index View
    config.view.online_contents
    config.view.online_contents.display_control = false

    ##
    # DUL Customization for listing children of components
    # Child Components Index View
    # Modeled after Online Contents
    config.view.child_components
    config.view.child_components.display_control = false
    config.view.child_components.partials = %i[index_child_components_nestable]
    # config.view.child_components.partials = %i[index_child_components]

    ##
    # Collection Context
    config.view.collection_context
    config.view.collection_context.display_control = false
    config.view.collection_context.partials = %i[index_collection_context]

    # DUL CUSTOMIZATION: remove compact index view in favor of just
    # having one index view type (and keeping it fairly sparse)
    ##
    # Compact index view
    # config.view.compact
    # config.view.compact.partials = %i[arclight_index_compact]
  end
end
