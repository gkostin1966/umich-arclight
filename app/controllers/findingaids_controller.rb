class FindingaidsController < ApplicationController
  layout "application"
  before_action :set_findingaid, only: %i[ show edit update destroy ]

  # GET /findingaids or /findingaids.json
  def index
    ingest_findingaids
    @findingaids = Findingaid.all.order(:slug)
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
        format.html { redirect_to findingaid_url(@findingaid), notice: "Findingaid was successfully created." }
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
        format.html { redirect_to findingaid_url(@findingaid), notice: "Findingaid was successfully updated." }
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
      format.html { redirect_to findingaids_url, notice: "Findingaid was successfully destroyed." }
      format.json { head :no_content }
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
      env = { }
      dir = Rails.root.join('tmp/findingaids')
      Dir.mkdir(dir) unless Dir.exist?(dir)
      # cmd = "rclone move remote: #{dir}"
      cmd = "rclone copy remote: #{dir}"

      stdout_and_stderr, process_status = Open3.capture2e(env, cmd)

      if process_status.success?
        Dir.open(dir) do |d|
          d.each_child do |fn|
            path = "#{dir}/#{fn}"
            unless File.directory?(path)
              File.open(path, 'r:UTF-8') do |f|
                findingaid = Findingaid.new
                findingaid.filename = fn
                findingaid.content = f.read
                findingaid.md5sum = Digest::MD5.hexdigest findingaid.content
                findingaid.sha1sum = Digest::SHA1.hexdigest findingaid.content
                f.rewind
                doc = Nokogiri::XML(f)
                findingaid.eadid = doc.at_xpath('/ead/eadheader/eadid').text.strip
                findingaid.slug = ead_slug(findingaid.eadid)
                findingaid.eadurl = ead_url(findingaid.eadid)
                findingaid.state = "read"
                findingaid.error = ""
                findingaid.save unless Findingaid.find_by(md5sum: findingaid.md5sum)
              end
            end
            FileUtils.rm_r(path)
          end
        end
      end
   end
  
    def ead_slug(ead_id)
      m = /^[^-]*-([^-]+)-.*$/.match(ead_id)
      return "" unless m
      m[1]
    end
  
    def ead_url(ead_id) 
      "#{ead_id}"
    end
end
