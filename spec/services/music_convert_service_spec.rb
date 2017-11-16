# frozen_string_literal: true

require 'rails_helper'

describe MusicConvertService do
  it 'converts into a video file with specified options' do
    skip 'it fails with ffprobe of the CI'

    extend ActionDispatch::TestProcess

    track = Fabricate(
      :track,
      title: 'title',
      artist: 'artist',
      music: fixture_file_upload('files/high.mp3'),
      video_image: fixture_file_upload('files/attachment.jpg'),
    )

    file = MusicConvertService.new.call(track, '1920x1080')

    expect(`ffprobe -v error -show_entries tags=title -of default=noprint_wrappers=1:nokey=1 #{file.path}`).to eq "title\n"
    expect(`ffprobe -v error -show_entries tags=artist -of default=noprint_wrappers=1:nokey=1 #{file.path}`).to eq "artist\n"
    expect(`ffprobe -v error -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 #{file.path}`).to eq "1920\n"
    expect(`ffprobe -v error -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 #{file.path}`).to eq "1080\n"
  end

  it 'uses default artwork if artwork is missing' do
    skip 'it fails with ffprobe of the CI'

    extend ActionDispatch::TestProcess

    track = Fabricate(
      :track,
      title: 'title',
      artist: 'artist',
      music: fixture_file_upload('files/high.mp3'),
      video_image: nil,
    )

    file = MusicConvertService.new.call(track, '1920x1080')

    # See if the video stream actually exists.
    expect(`ffprobe -v error -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 #{file.path}`).to eq "1920\n"
    expect(`ffprobe -v error -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 #{file.path}`).to eq "1080\n"
  end

  it 'raises Mastodon::MusicvideoError after genmv failed' do
    extend ActionDispatch::TestProcess

    track = Fabricate.build(
      :track,
      video_image: fixture_file_upload('files/high.mp3')
    )
    track.save! validate: false

    expect { MusicConvertService.new.call(track, '720x720') }.to raise_error Mastodon::MusicvideoError
  end
end
