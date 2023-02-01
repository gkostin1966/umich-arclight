# frozen_string_literal: true

require 'arclight'
require 'benchmark'
require 'json'
require 'fileutils'
require 'nokogiri'

Deprecation.default_deprecation_behavior = :silence

module UmArclight
  module Package
    # Generate HTML and PDF packages of finding aids
    class Generator # rubocop:disable Metrics/ClassLength
      COMPONENT_FIELDS = %w[
        id
        parent_ssi
        parent_ssim
        ref_ssi
        ref_ssm
        ead_ssi
        abstract_tesim
        scopecontent_tesim
        component_level_isim
        normalized_title_ssm
        level_ssm
        scopecontent_teism
        unitid_ssm
        odd_tesim
        bioghist_tesim
        total_digital_object_count_isim
        digital_objects_ssm
        containers_ssim
        repository_ssm
      ].freeze

      attr_accessor :identifier, :doc, :fragment, :collection, :session

      def initialize(identifier:)
        @identifier = identifier
        @collection = nil
        @session = ActionDispatch::Integration::Session.new(Rails.application)
        @session.host = 'findingaids.lib.umich.edu'
        @session.https!(true)
      end

      def build_html
        components = []
        elapsed_time = Benchmark.realtime do
          @collection = fetch_doc(identifier)
          components = fetch_components(@collection.eadid)
        end

        response = get("/catalog/#{@collection.id}")
        @doc = Nokogiri::HTML5(response.body)

        puts "UM-Arclight generate package : #{collection.id} : fetch components (in #{elapsed_time.round(3)} secs)."
        elapsed_time = Benchmark.realtime do
          @fragment = render_fragment(
            collection: collection,
            components: components
          )

          update_navigation_links
          update_package_html
        end
        puts "UM-Arclight generate package : #{collection.id} : build HTML (in #{elapsed_time.round(3)} secs)."
      end

      def generate_html
        build_html

        output_filename = generate_output_filename('.html')
        FileUtils.makedirs(File.dirname(output_filename)) unless Dir.exist?(File.dirname(output_filename))

        File.open(output_filename, 'w') do |f|
          f.puts doc.serialize
        end
      end

      def build_pdf
        # build the source in tmp
        FileUtils.mkdir_p(working_path_name)
        Dir.chdir(working_path_name)
        FileUtils.mkdir_p('assets')

        elapsed_time = Benchmark.realtime do
          update_package_html_pdf
          update_package_styles_pdf
          update_package_scripts_pdf
          # set the media
          doc.root['data-media'] = 'print'
        end
        puts "UM-Arclight generate package: #{collection.id} : update HTML for PDF (in #{elapsed_time.round(3)} secs)."
      end

      def generate_pdf # rubocop:disable Metrics/MethodLength
        generate_html if @doc.nil?

        build_pdf

        local_html_filename = "#{collection.document_id}.local.html"
        File.open(local_html_filename, 'w') do |f|
          f.puts doc.serialize
        end

        output_filename = generate_output_filename('.pdf')
        FileUtils.mkdir_p(File.dirname(output_filename))

        elapsed_time = Benchmark.realtime do
          Puppeteer.launch(headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox']) do |browser|
            page = browser.new_page
            page.goto("file:#{working_path_name}/#{@collection.document_id}.local.html", wait_until: 'networkidle2')
            page.pdf(
              path: output_filename,
              print_background: true,
              omit_background: false,
              display_header_footer: false,
              timeout: (2 * 300_000),
              footer_template: '<div style="font-weight: bold">Generated by findingaids.lib.umich.edu</div>',
              margin: {
                top: 50,
                right: 100,
                bottom: 70,
                left: 70
              }
            )
          end
        end

        File.unlink(local_html_filename) unless ENV.fetch('DEBUG_GENERATOR', 'FALSE') == 'TRUE'

        puts "UM-Arclight generate package: #{collection.id} : puppeteer render (in #{elapsed_time.round(3)} secs)."
      end

      private

      def generate_output_filename(ext)
        filename = "#{DulArclight.finding_aid_data}/pdf/#{collection.repository_id}/#{collection.document_id}#{ext}"
        filename = File.join(Rails.root, filename) if filename.start_with?('./')
        filename
      end

      def working_path_name
        "#{Rails.root}/tmp/pdf"
      end

      def get(url)
        if url.start_with?('/assets/') && File.exist?(File.join(Rails.root, 'public', url))
          contents = File.read(File.join(Rails.root, 'public', url))
          response = OpenStruct.new
          response.body = contents
          return response
        end
        session.get(url)
        session.response
      end

      def fetch_doc(id)
        params = {
          fl: '*',
          q: ["id:#{id.tr(".", "-")}"],
          start: 0,
          rows: 1
        }
        response = index.search(params)
        response.documents.first
      end

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/MethodLength
      def fetch_components(id)
        params = {
          fl: COMPONENT_FIELDS.join(','),
          q: ["ead_ssi:#{id}"],
          sort: 'sort_ii asc, title_sort asc',
          start: 0,
          rows: 1000
        }
        components = []
        tmp = {}
        tmp_map = {}
        component_mapper = {}
        response = index.search(params)
        start = 0
        while response.documents.present?
          puts "UM-Arclight generate package : harvesting components : #{collection.id} : #{start} / #{response.total}"
          response.documents.each do |doc|
            if doc.component_level.nil?
              # ignore the collection doc
              next
            end

            tmp[doc.component_level] = [] if tmp[doc.component_level].nil?
            tmp[doc.component_level] << doc
            tmp_map[doc.reference] = doc
          end
          start += 1000
          params[:start] = start
          response = index.search(params)
        end

        # now attach child components
        tmp.keys.sort.each do |component_level|
          next if component_level == 1

          tmp[component_level].each do |doc|
            # find the parent_doc because nothing is easy
            parent_doc = nil
            doc.parent_ids_keyed.reverse.each do |parent_id|
              if tmp_map[parent_id]
                parent_doc = tmp_map[parent_id]
                break
              end
            end

            component_mapper[parent_doc.reference] = [] if component_mapper[parent_doc.reference].nil?
            component_mapper[parent_doc.reference].unshift doc
          end
        end

        # now flatten this into components?
        queue = [tmp[1]].flatten
        until queue.empty?
          doc = queue.shift
          components << doc
          component_mapper.fetch(doc.reference, []).each do |v|
            queue.unshift v
          end
        end

        components
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

      def render_fragment(variables)
        paths = ActionView::PathSet.new(['app/views'])
        lookup_context = ActionView::LookupContext.new(paths)
        renderer = ActionView::Renderer.new(lookup_context)
        view_context = ActionView::Base.new(renderer)
        view_context.assign(variables)
        view_context.extend Arclight::EadFormatHelpers

        fragment_html = renderer.render(view_context, template: 'arclight/fragments/fragment')
        Nokogiri::HTML5(fragment_html)
      end

      def update_navigation_links
        doc.css('#about-collection-nav a').each do |link|
          href = link['href']
          link['href'] = '#' + href.split('#').last
        end
      end

      # rubocop:disable Metrics/AbcSize
      def update_package_html
        last_style_el = doc.xpath('/html/head/link[@rel="stylesheet"]').last
        last_style_el.add_next_sibling(fragment.css('#utility-styles').first)
        @chunks = doc.fragment
        asset_links = doc.xpath('/html/head/link[starts-with(@href, "/assets")]')
        # add the placeholder
        asset_links.first.add_previous_sibling '<m-arclight-placeholder></m-arclight-placeholder>'
        asset_links.each do |el|
          @chunks << el
        end

        @chunks << doc.xpath('/html/head/script[starts-with(@src, "/assets")]')
        @chunks << doc.css('meta[name="csrf-param"]').first&.unlink
        @chunks << doc.css('meta[name="csrf-token"]').first&.unlink

        doc.css('#summary dl').first << fragment.css('dl#ead_author_block dt,dd')
        doc.css('#background').first << fragment.css('#revdesc_changes')
        doc.css('div.al-contents').first.replace(fragment.css('div.al-contents-ish').first)
        doc.css('.card-img').first.remove
        doc.css('#navigate-collection-toggle').first.remove
        doc.css('#context-tree-nav .tab-pane.active').first.inner_html = ''
        doc.css('#context-tree-nav .tab-pane.active').first << fragment.css('#toc').first
      end
      # rubocop:enable Metrics/AbcSize

      def update_package_html_pdf
        build_package_html_toc
        doc.css('m-website-header').first.replace(fragment.css('header').first)
        doc.css('footer').first.remove
        doc.css('div.x-printable').remove
      end

      def build_package_html_toc
        # rearrange the various contents links
        doc.css('.access-preview-snippet').first.inner_html = '<div id="toc"><ul class="list-unbulleted"></ul></ul>'
        current_ul = doc.css('#toc ul').first
        contents_li = nil
        doc.css('#about-collection-nav li.nav-item').each do |li|
          current_ul << li
          contents_li = li if li.css('a').first['href'] == '#contents'
        end
        return unless contents_li

        contents_ul = doc.css('#sidebar #toc > ul').first
        contents_ul['class'] = 'list-unbulleted'
        contents_li << contents_ul
      end

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/MethodLength
      def update_package_styles_pdf
        # restore the stylesheet links for the PDF
        placeholder_el = doc.css('m-arclight-placeholder').first
        @chunks.css('link').each do |link|
          next unless link['rel'] == 'stylesheet' && link['href'].start_with?('/assets/')

          response = get(link['href'])
          stylesheet = response.body

          # now we have to look for url(/assets) here
          buffer = stylesheet.split(/\n/)
          buffer.each_with_index do |line, i|
            next unless (matches = line.scan(%r{url\(\/assets\/([^\)]+)\)}))

            matches.each do |match|
              asset_path = match[0]
              filename = asset_path.split(/[\?#]/).first

              unless File.exist?("assets/#{filename}")
                response = get("/assets/#{asset_path}")
                resource = response.body

                FileUtils.makedirs("assets/#{File.dirname(filename)}") unless Dir.exist?(File.dirname("assets/#{filename}"))

                File.open("./assets/#{filename}", 'wb') do |f|
                  f.puts resource
                end
              end

              line.gsub!("/assets/#{asset_path}", "./#{filename}")
            end
            buffer[i] = line
          end

          filename = link['href'].split(/[\?#]/).first

          FileUtils.makedirs(".#{File.dirname(filename)}") unless Dir.exist?(".#{File.dirname(filename)}")

          File.open(".#{filename}", 'wb') do |f|
            f.puts buffer.join("\n")
          end
          link['href'] = ".#{filename}"
          placeholder_el.add_next_sibling link
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

      def update_package_scripts_pdf
        # remove the script tags
        doc.xpath('/html/head/script').each do |script| # rubocop:disable Style/SymbolProc
          script.remove
        end
      end

      def index
        @index ||= Index.new
      end
    end

    # Queue packaging
    class Queue
      attr_accessor :index

      def initialize
        @index = Index.new
      end

      def setup(**kw)
        identifiers = if kw[:eadid]
          [kw[:eadid].tr('.', '-')]
        else
          fetch_collection_identifiers(kw[:repository_ssm])
        end

        identifiers.each do |identifier|
          puts "UM-Arclight queue package: #{identifier}"
          ::PackageFindingAidJob.perform_later(identifier)
        end
      end

      def fetch_collection_identifiers(repository_ssm)
        params = {
          fl: 'id',
          q: ['level_ssm:collection'],
          start: 0,
          rows: 1000
        }
        params['fq'] = ["repository_ssm:\"#{repository_ssm}\""] if repository_ssm
        identifiers = []
        response = index.search(params)
        start = 0
        while response.documents.present?
          response.documents.each do |doc|
            identifiers << doc.id
          end
          start += 1000
          params[:start] = start
          response = index.search(params)
        end
        identifiers
      end
    end

    # Shared helper to Blacklight.repository
    class Index
      attr_accessor :index
      def initialize
        @index = Blacklight.repository_class.new(CatalogController.new.helpers.blacklight_config)
      end

      def search(params)
        @index.search(params)
      end
    end
  end
end
