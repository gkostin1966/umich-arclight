class SlugmapsController < ApplicationController
  layout "controller"
  before_action :set_slugmap, only: %i[show edit update destroy]

  # GET /slugmaps or /slugmaps.json
  def index
    @slugmaps = Slugmap.order(:reposlug, :corpname)
  end

  # GET /slugmaps/1 or /slugmaps/1.json
  def show
  end

  # GET /slugmaps/new
  def new
    @slugmap = Slugmap.new
  end

  # GET /slugmaps/1/edit
  def edit
  end

  # POST /slugmaps or /slugmaps.json
  def create
    @slugmap = Slugmap.new(slugmap_params)

    respond_to do |format|
      if @slugmap.save
        format.html { redirect_to slugmap_url(@slugmap), notice: "Slugmap was successfully created." } # rubocop:disable Rails/I18nLocaleTexts
        format.json { render :show, status: :created, location: @slugmap }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @slugmap.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /slugmaps/1 or /slugmaps/1.json
  def update
    respond_to do |format|
      if @slugmap.update(slugmap_params)
        format.html { redirect_to slugmap_url(@slugmap), notice: "Slugmap was successfully updated." } # rubocop:disable Rails/I18nLocaleTexts
        format.json { render :show, status: :ok, location: @slugmap }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @slugmap.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /slugmaps/1 or /slugmaps/1.json
  def destroy
    @slugmap.destroy

    respond_to do |format|
      format.html { redirect_to slugmaps_url, notice: "Slugmap was successfully destroyed." } # rubocop:disable Rails/I18nLocaleTexts
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_slugmap
    @slugmap = Slugmap.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def slugmap_params
    params.require(:slugmap).permit(:corpname, :reposlug)
  end
end
