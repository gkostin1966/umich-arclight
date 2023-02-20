class FindingaidsController < ApplicationController
  layout "application"
  before_action :set_findingaid, only: %i[show edit update destroy reindex]

  # GET /findingaids or /findingaids.json
  def index
    ingest_findingaids
    # @findingaids = Findingaid.all.order(:slug)
    @findingaids = Findingaid.all
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
    @findingaid = Findingaid.new(findingaid_params)

    respond_to do |format|
      if @findingaid.save
        format.html { redirect_to findingaid_url(@findingaid), notice: "Finding aid was successfully created." }  # rubocop:disable Rails/I18nLocaleTexts
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
      if @findingaid.update(findingaid_params)
        format.html { redirect_to findingaid_url(@findingaid), notice: "Finding aid was successfully updated." }  # rubocop:disable Rails/I18nLocaleTexts
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

  # PATCH/PUT /findingaids/1/reindex
  def reindex
    env = {'REPOSITORY_ID' => @findingaid.slug}
    cmd = "bundle exec traject -u #{ENV.fetch("SOLR_URL", Blacklight.default_index.connection.base_uri).to_s.chomp("/")} -i xml -c ./lib/dul_arclight/traject/ead2_config.rb --stdin"

    stdout_and_stderr, process_status = Open3.capture2e(env, cmd, stdin_data: @findingaid.content.force_encoding(Encoding::UTF_8))

    if process_status.success?
      @findingaid.destroy
    else
      @findingaid.errors.add :content, stdout_and_stderr unless process_status.success?
    end

    respond_to do |format|
      if process_status.success?
        format.html { redirect_to solr_document_url(@findingaid.eadurl), notice: "Finding aid was successfully reindexed." } # rubocop:disable Rails/I18nLocaleTexts
        format.json { render :show, status: :ok, location: @findingaid }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @findingaid.errors, status: :unprocessable_entity }
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
    params.require(:findingaid).permit(:filename, :content, :md5sum, :sha1sum, :slug, :eadid, :eadurl, :state, :error)
  end

  def ingest_findingaids
    env = {}
    dir = Rails.root.join('tmp/findingaids')
    Dir.mkdir(dir) unless Dir.exist?(dir)
    cmd = "rclone move remote: #{dir}"
    # cmd = "rclone copy remote: #{dir}"

    stdout_and_stderr, process_status = Open3.capture2e(env, cmd)

    if process_status.success?
      Dir.open(dir) do |d|
        d.each_child do |fn|
          path = "#{dir}/#{fn}"
          unless File.directory?(path)
            File.open(path, "r:UTF-8:UTF-8") do |f|
              findingaid = Findingaid.new
              findingaid.filename = fn
              findingaid.content = f.read
              findingaid.md5sum = Digest::MD5.hexdigest findingaid.content
              findingaid.sha1sum = Digest::SHA1.hexdigest findingaid.content
              f.rewind
              doc = Nokogiri::XML(f)
              findingaid.eadid = doc.at_xpath('/ead/eadheader/eadid').text.strip
              findingaid.eadurl = ead_url(findingaid.eadid)
              findingaid.slug = ead_slug(findingaid.eadid, doc.at_xpath('/ead/archdesc/did/repository/corpname').text.strip)
              findingaid.state = "read"
              findingaid.error = ""
              findingaid.save unless Findingaid.find_by(md5sum: findingaid.md5sum)
            end
          end
          FileUtils.rm_r(path)
        end
      end
    else
      raise StandardError.new(stdout_and_stderr)
    end
  end

  def ead_url(eadid)
    eadid.tr(".", "-").to_s
  end

  def ead_slug(_eadid, corpname)
    name = case corpname
    when "University of Michigan Library (Special Collections Research Center)"
      "University of Michigan Special Collections Research Center"
    when "William L. Clements Library, University of Michigan"
      "University of Michigan William L. Clements Library"
    when "Clarke Historical Library, Central Michigan University"
      "Central Michigan University Clarke Historical Library"
    when "Bentley Historical Library"
      "University of Michigan Bentley Historical Library"
    else
      corpname
    end
    Arclight::Repository.find_by(name: name)&.slug || ""
  end
end
