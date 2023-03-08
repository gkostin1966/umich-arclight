class FindingaidsController < ApplicationController
  layout "controller"
  before_action :set_findingaid, only: %i[show edit update destroy reindex]

  # GET /findingaids or /findingaids.json
  def index
    @findingaids = Findingaid.order(updated_at: :desc)
    # @findingaids = Findingaid.all
  end

  # GET /findingaids/1 or /findingaids/1.json
  def show
  end

  # GET /findingaids/new
  def new
    @findingaid = Findingaid.new
  end

  # GET /findingaids/1/edit
  def edit
  end

  # POST /findingaids or /findingaids.json
  def create
    @findingaid = Findingaid.new

    @findingaid.filename = ""
    @findingaid.content = ""
    @findingaid.md5sum = ""
    @findingaid.sha1sum = ""
    @findingaid.corpname = ""
    @findingaid.reponame = ""
    @findingaid.reposlug = ""
    @findingaid.eadid = ""
    @findingaid.eadslug = ""
    @findingaid.eadurl = ""
    @findingaid.state = ""
    @findingaid.error = ""

    success = false

    uploaded_file = findingaid_params[:content]
    if uploaded_file
      @findingaid.filename = uploaded_file.original_filename
      @findingaid.content = uploaded_file.read
      @findingaid.md5sum = Digest::MD5.hexdigest @findingaid.content
      @findingaid.sha1sum = Digest::SHA1.hexdigest @findingaid.content

      @findingaid.error = +""
      doc = nil

      # Parse Validation
      begin
        if @findingaid.error.blank?
          doc = Nokogiri::XML(@findingaid.content)
          if doc.errors.present?
            @findingaid.error = "Error XML parse: " + errors.join("<br>")
            @findingaid.state = "errored"
          end
        end
      rescue => e
        @findingaid.error = "Exception XML parse: " + e.message
        @findingaid.state = "errored"
      end

      # DTD Validation
      begin
        if @findingaid.error.blank?
          Dir.chdir(Rails.root.join("data/ead2002")) # Directory where ead.dtd is stored locally.
          options = Nokogiri::XML::ParseOptions::DEFAULT_XML | Nokogiri::XML::ParseOptions::DTDLOAD | Nokogiri::XML::ParseOptions::DTDVALID
          doc_with_dtd_loaded = Nokogiri::XML::Document.parse(@findingaid.content, nil, nil, options)
          errors = doc_with_dtd_loaded.external_subset&.validate(doc_with_dtd_loaded)
          if errors.present?
            @findingaid.error = "Error XML DTD validate: " + errors.join("<br>")
            @findingaid.state = "errored"
          end
        end
      rescue => e
        @findingaid.error = "Exception XML DTD validate: " + e.message
        @findingaid.state = "errored"
      ensure
        Dir.chdir(Rails.root)
      end

      # DTD to Schema Transform Validation
      doc_with_xlink = nil
      begin
        if @findingaid.error.blank?
          stylesheet = Nokogiri::XSLT.parse(Rails.root.join("data/ead2002/dtd2schema.xsl").read)
          doc_with_xlink = stylesheet.transform(doc)
          if doc_with_xlink.errors.present?
            @findingaid.error = "Error XML transform: " + errors.join("<br>")
            @findingaid.state = "errored"
          end
        end
      rescue => e
        @findingaid.error = "Exception XML transform: " + e.message
        @findingaid.state = "errored"
      end

      # Schema Validation
      begin
        if @findingaid.error.blank?
          schema = Nokogiri::XML::Schema(Rails.root.join("data/ead2002/ead2002.xsd").read, Nokogiri::XML::ParseOptions::DEFAULT_SCHEMA & ~Nokogiri::XML::ParseOptions::NONET)
          errors = schema.validate(doc_with_xlink)
          if errors.present?
            @findingaid.error = @findingaid.error = "Error XML schema validate: " + errors.join("; ")
            @findingaid.state = "errored"
          end
        end
      rescue => e
        @findingaid.error = "Exception XML schema validate: " + e.message
        @findingaid.state = "errored"
      end

      # rubocop:disable Lint/UselessAssignment
      begin
        if @findingaid.error.blank?
          doc.remove_namespaces!

          cmd = "@findingaid.eadid = doc.at_xpath('/ead/eadheader/eadid').text.strip"
          @findingaid.eadid = doc.at_xpath('/ead/eadheader/eadid').text.strip

          cmd = "@findingaid.eadslug = ead_slug(@findingaid.eadid)"
          @findingaid.eadslug = ead_slug(@findingaid.eadid)

          cmd = "@findingaid.corpname = doc.at_xpath('/ead/archdesc/did/repository/corpname').text.strip"
          @findingaid.corpname = doc.at_xpath('/ead/archdesc/did/repository/corpname').text.strip

          cmd = "@findingaid.reposlug = repo_slug(@findingaid.eadid, @findingaid.corpname)"
          @findingaid.reposlug = repo_slug(@findingaid.eadid, @findingaid.corpname)
        end
      rescue => e
        @findingaid.error = "Exception XML xpath #{cmd}: " + e.message
        @findingaid.state = "errored"
      end
      # rubocop:enable Lint/UselessAssignment

      @findingaid.state = "uploaded" if @findingaid.error.blank?

      success = @findingaid.save
    else
      @findingaid.errors.add(:content, "missing file")
    end

    respond_to do |format|
      if success
        format.html { redirect_to edit_findingaid_url(@findingaid), notice: "Finding aid was successfully uploaded." }  # rubocop:disable Rails/I18nLocaleTexts
        format.json { render :show, status: :created, location: @findingaid }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @findingaid.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /findingaids/1 or /findingaids/1.json
  def update
    respond_to do |format|
      if @findingaid.reposlug.blank? && findingaid_params[:reposlug].present?
        slugmap = Slugmap.find_by(corpname: @findingaid.corpname)
        if slugmap.present?
          slugmap.update(reposlug: findingaid_params[:reposlug])
        else
          Slugmap.create(corpname: @findingaid.corpname, reposlug: findingaid_params[:reposlug])
        end
      end

      if @findingaid.update(findingaid_params)
        format.html { redirect_to findingaids_url }  # rubocop:disable Rails/I18nLocaleTexts
        format.json { render :show, status: :ok, location: @findingaid }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @findingaid.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /findingaids/1 or /findingaids/1.json
  def destroy
    @findingaid.destroy

    respond_to do |format|
      format.html { redirect_to findingaids_url, notice: "Finding aid was successfully destroyed." }  # rubocop:disable Rails/I18nLocaleTexts
      format.json { head :no_content }
    end
  end

  # PUT /findingaids/1/reindex
  def reindex
    traject_indexer = Traject::Indexer::NokogiriIndexer.new(
      # disable Indexer processing thread pool, to keep things simple and not interfering with Rails.
      "processing_thread_pool" => 0,
      "solr_writer.thread_pool" => 0, # writing to solr is done inline, no threads

      "solr.url" => ENV.fetch("SOLR_URL", Blacklight.default_index.connection.base_uri).to_s.chomp("/"),
      "writer_class" => "SolrJsonWriter",
      "solr_writer.batch_size" => 1, # send to solr for each record, no batching
      "solr_writer.commit_on_close" => true,
      "repository" => @findingaid.reposlug
    ) do
      load_config_file(Rails.root.join("lib/dul_arclight/traject/ead2_config.rb"))
    end

    success = true
    error_message = nil
    begin
      # Now, wherever you want, simply:
      traject_indexer << Nokogiri::XML(@findingaid.content.force_encoding(Encoding::UTF_8)).remove_namespaces!
    rescue => e
      success = false
      error_message = e.message
    else
      traject_indexer.complete
    end

    if success
      @findingaid.state = "indexed"
      @document = greg_fetch_doc(@findingaid.eadid)
      if @document.present?
        @findingaid.eadurl = @document['title_ssm']&.first
        if @findingaid.eadurl.present?
          dest_path = File.join(DulArclight.finding_aid_data, "xml", @findingaid.reposlug)
          FileUtils.mkdir_p(dest_path)
          dest = File.join(dest_path, "#{@findingaid.eadslug}.xml")
          # FileUtils.copy_file(path, dest, preserve: true, dereference: true, remove_destination: true)
          File.write(dest, @findingaid.content)
          ::IngestAutomationJob.perform_later('index.success', src_path: dest, archive_path: dest, ead_id: @findingaid.eadslug)
        else
          success = false
          error_message = "@document['title_ssm'] missing???"
          @findingaid.state = "errored"
          @findingaid.errors.add :content, error_message
          @findingaid.error = error_message
        end
      else
        success = false
        error_message = "fetch_doc(#{@findingaid.eadid}) returned nil????"
        @findingaid.state = "errored"
        @findingaid.errors.add :content, error_message
        @findingaid.error = error_message
      end
    else
      @findingaid.state = "errored"
      @findingaid.errors.add :content, error_message
      @findingaid.error = error_message
    end

    @findingaid.save

    respond_to do |format|
      if success
        format.html { redirect_to findingaid_url(@findingaid), notice: "Finding aid was successfully indexed." } # rubocop:disable Rails/I18nLocaleTexts
        format.json { render :show, status: :ok, location: @findingaid }
      else
        format.html { render :show, status: :unprocessable_entity }
        format.json { render :show, status: :unprocessable_entity }
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_findingaid
    @findingaid = Findingaid.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def findingaid_params
    params.require(:findingaid).permit(:filename, :content, :md5sum, :sha1sum, :corpname, :reponame, :reposlug, :eadid, :eadslug, :eadurl, :state, :error)
  end

  def ead_slug(eadid)
    eadid.tr(".", "-").to_s
  end

  def repo_slug(_eadid, corpname)
    # name = case corpname
    # when "University of Michigan Library (Special Collections Research Center)"
    #   "University of Michigan Special Collections Research Center"
    # when "William L. Clements Library, University of Michigan"
    #   "University of Michigan William L. Clements Library"
    # when "Clarke Historical Library, Central Michigan University"
    #   "Central Michigan University Clarke Historical Library"
    # when "Bentley Historical Library"
    #   "University of Michigan Bentley Historical Library"
    # else
    #   corpname
    # end

    slugmap = Slugmap.find_by(corpname: corpname)
    reposlug = slugmap&.reposlug || ""
    Arclight::Repository.find_by(slug: reposlug)&.slug || ""
  end

  def greg_fetch_doc(id)
    params = {
      fl: '*',
      q: ["id:#{ead_slug(id)}"],
      start: 0,
      rows: 1
    }
    response = greg_index.search(params)
    response.documents.first
  end

  def greg_index
    @greg_index ||= GregIndex.new
  end
end

class GregIndex
  attr_accessor :index
  def initialize
    @index = Blacklight.repository_class.new(CatalogController.new.helpers.blacklight_config)
  end

  def search(params)
    @index.search(params)
  end
end
