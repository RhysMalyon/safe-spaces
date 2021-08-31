class SpacesController < ApplicationController
  before_action :set_space, only: %i[show edit update destroy]
  skip_before_action :authenticate_user!, only: %i[index show]

  def index
    @user = current_user
    if params[:query].present?
      coordinates = Geocoder.search(params[:query]).first.data["center"]
      @markers = [
        {
          lng: coordinates[0],
          lat: coordinates[1]
        }
      ]
    end
    set_space_markers
    set_koban_markers
    @incident = Incident.new
  end

  def new
    @space = Space.new
    authorize @space
  end

  def create
    @space = Space.new(space_params)
    @space.user = current_user
    authorize @space
    if @space.save
      redirect_to user_path(current_user), notice: 'Space was successfully created.'
    else
      render :new
    end
  end

  def show
    @user = current_user
    @space_address = @space.address
    @markers = [
      {
        lat: @space.latitude,
        lng: @space.longitude,
        infoWindow: { content: render_to_string(partial: "/spaces/info_window", locals: { space: @space }) },
        image_url: helpers.asset_url(Cloudinary::Utils.cloudinary_url(@space.user.photo.key))
      }
    ]
    set_space_markers
    set_koban_markers
    @incident = Incident.new
    @spaces = Space.near([@space.latitude, @space.longitude], 15).where(available: true).reject do |space|
      @user.spaces.find do |user_space|
        space == user_space
      end
    end
    @notification = SpaceNotification.with(space: @space, recipient: @recipient)
    # @notification.deliver(User.all)
    @spaces.each do |space|
      @notification.deliver(User.where(spaces: space))
    end
  end

  def edit; end

  def update
    @user = current_user
    respond_to do |format|
      if @space.update(space_params)
        format.html { redirect_to user_path(@user), notice: 'Your space has been updated' }
        format.js
      else
        format.html { render :edit }
        format.js
      end
    end
  end

  def destroy
    @user = current_user
    authorize @space
    @space.destroy
    redirect_to user_path(@user), notice: 'Your space was successfully removed'
  end

  private

  def set_space
    @space = Space.find(params[:id])
    authorize @space
  end

  def space_params
    params.require(:space).permit(:conditions, :available, :address, :photo)
  end

  def require_login
    unless signed_in?
      flash[:error] = "You must be logged in to access this section"
      redirect_to new_user_session_url # halts request cycle
    end
  end

  def set_koban_markers
    @kobans = policy_scope(Koban)
    @koban_markers = @kobans.map do |koban|
      {
        lat: koban.latitude,
        lng: koban.longitude,
        info_window: render_to_string(partial: "/spaces/koban_info_window", locals: { koban: koban }),
        image_url: helpers.asset_url('police2.png')
      }
    end
  end

  def set_space_markers
    @user = current_user
    @spaces = policy_scope(Space)
    @spaces_location = Space.where.not(latitude: nil, longitude: nil)
    @spaces_available = @spaces_location.where(available: true)
    @space_markers = @spaces_available.map do |space|
      {
        lat: space.latitude,
        lng: space.longitude,
        info_window: render_to_string(partial: "/spaces/info_window", locals: { space: space }),
        image_url: helpers.asset_url(Cloudinary::Utils.cloudinary_url(space.user.photo.key))
      }
    end
  end
end
