class Api::V1::Albums::TracksController < Api::BaseController
  before_action -> { doorkeeper_authorize! :write }, except: :index
  before_action :require_user!, except: :index
  rescue_from Mastodon::TrackNotFoundError, with: :render_track_not_found

  respond_to :json

  def update
    position = AlbumMusicAttachment.position_between(
      *range(
        params[:previous_id]&.to_i,
        params[:next_id]&.to_i,
        AlbumMusicAttachment::MIN_POSITION,
        AlbumMusicAttachment::MAX_POSITION,
      )
    )

    if request.put?
      AlbumMusicAttachment.create!(
        album_id: params.require(:album_id),
        music_attachment_id: params.require(:id),
        position: position,
      )
    else
      AlbumMusicAttachment.find_by!(
        album_id: params.require(:album_id),
        music_attachment_id: params.require(:id),
      ).update! position: position
    end

    render_empty
  end

  def destroy
    AlbumMusicAttachment.find_by!(
      album_id: params.require(:album_id),
      music_attachment_id: params.require(:id),
    ).destroy!

    render_empty
  end

  def index
    ranged = range(params[:since_id]&.to_i, params[:max_id]&.to_i, nil, nil)

    album_music_attachment_scope =
      AlbumMusicAttachment.where(album_id: params.require(:album_id)).order(:position)

    if ranged[0].present?
      album_music_attachment_scope = album_music_attachment_scope.where('position > ?', ranged[0])
    end

    if ranged[1].present?
      album_music_attachment_scope = album_music_attachment_scope.where('position < ?', ranged[1])
    end

    @tracks = MusicAttachment.joins(:album_music_attachment)
                             .merge(album_music_attachment_scope)
                             .limit(limit_param(DEFAULT_TRACKS_LIMIT))
  end

  private

  def render_track_not_found
    render json: { error: I18n.t('albums.tracks.positioning_not_found') }, status: :unprocessable_entity
  end

  def range(lower_id, upper_id, lower_position_fallback, upper_position_fallback)
    positioning_ids = [lower_id, upper_id].compact

    lower_position = lower_position_fallback
    upper_position = upper_position_fallback

    positioning_attributes = AlbumMusicAttachment.where(
      music_attachment_id: positioning_ids,
      album_id: params.require(:album_id),
    ).pluck(:music_attachment_id, :position)

    if positioning_attributes.size < positioning_ids.size
      raise Mastodon::TrackNotFoundError
    end

    positioning_attributes.each do |attributes|
      case attributes[0]
      when lower_id
        lower_position = attributes[1]
      when upper_id
        upper_position = attributes[1]
      end
    end

    if upper_position.present? && lower_position.present? && upper_position <= lower_position
      raise Mastodon::ValidationError, I18n.t('albums.tracks.invalid_range')
    end

    [lower_position, upper_position]
  end
end
