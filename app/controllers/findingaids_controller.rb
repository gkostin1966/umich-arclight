class FindingaidsController < ApplicationController
  before_action :set_findingaid, only: %i[ show edit update destroy ]

  # GET /findingaids or /findingaids.json
  def index
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
end
