class FindingaidsController < ApplicationController
  layout "controller"
  before_action :set_findingaid, only: %i[show edit update destroy reindex]

  # GET /findingaids or /findingaids.json
  def index
    Findingaid.where("updated_at < ?", 30.days.ago).each do |findingaid|
      path = File.join(ENV["FINDING_AID_DATA"], "findingaids", findingaid.id.to_s)
      FileUtils.rm(path) if File.exist?(path)
      findingaid.destroy
    end
    @findingaids = Findingaid.order(updated_at: :desc)
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
    @findingaid.size = 0
    @findingaid.corpname = ""
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
      @findingaid.content = uploaded_file.content_type
      @findingaid.size = uploaded_file.size
      @findingaid.state = "uploaded"
      @findingaid.save!

      path = File.join(ENV["FINDING_AID_DATA"], "findingaids", @findingaid.id.to_s)
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.copy_file(uploaded_file.path, path)

      @findingaid.error = +""
      doc = nil

      # Parse Validation
      begin
        if @findingaid.error.blank?
          doc = Nokogiri::XML(uploaded_file)
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
          uploaded_file.rewind
          doc_with_dtd_loaded = Nokogiri::XML::Document.parse(uploaded_file, nil, nil, options)
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
            @findingaid.error = "Error XML schema validate: " + errors.join("; ")
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
    path = File.join(ENV["FINDING_AID_DATA"], "findingaids", @findingaid.id.to_s)
    FileUtils.rm(path) if File.exist?(path)
    @findingaid.destroy

    respond_to do |format|
      format.html { redirect_to findingaids_url, notice: "Finding aid was successfully destroyed." }  # rubocop:disable Rails/I18nLocaleTexts
      format.json { head :no_content }
    end
  end

  # PUT /findingaids/1/reindex
  def reindex
    IngestFindingAidJob.perform_later(@findingaid.id)
    @findingaid.state = "queued"

    respond_to do |format|
      if @findingaid.save
        format.html { redirect_to findingaid_url(@findingaid), notice: "Finding aid was successfully queued for ingest." } # rubocop:disable Rails/I18nLocaleTexts
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
    params.require(:findingaid).permit(:filename, :content, :size, :corpname, :reposlug, :eadid, :eadslug, :eadurl, :state, :error)
  end

  def ead_slug(eadid)
    eadid.tr(".", "-").to_s
  end

  def repo_slug(_eadid, corpname)
    slugmap = Slugmap.find_by(corpname: corpname)
    reposlug = slugmap&.reposlug || ""
    Arclight::Repository.find_by(slug: reposlug)&.slug || ""
  end

  def fetch_doc(id)
    params = {
      fl: '*',
      q: ["id:#{id}"],
      start: 0,
      rows: 1
    }
    repo = Blacklight.repository_class.new(CatalogController.new.helpers.blacklight_config)
    response = repo.search(params)
    response.documents.first
  end
end
