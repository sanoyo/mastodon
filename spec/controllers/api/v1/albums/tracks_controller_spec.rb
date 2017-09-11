# frozen_string_literal: true

require 'rails_helper'

describe Api::V1::Albums::TracksController, type: :controller do
  let(:album) { Fabricate(:album) }
  let(:music_attachment) { Fabricate(:music_attachment) }

  shared_examples 'position update' do |http_method|
    it 'processes position parameters' do
      previous_model = Fabricate(:album_music_attachment, album: album, position: '0.1')
      next_model = Fabricate(:album_music_attachment, album: album, position: '0.2')

      method(http_method).call :update, params: { album_id: album, id: music_attachment, previous_id: previous_model.music_attachment_id, next_id: next_model.music_attachment_id }

      subject_model = AlbumMusicAttachment.find_by!(album: album, music_attachment: music_attachment)
      expect(subject_model.position).to be_between(BigDecimal('0.1'), BigDecimal('0.2')).exclusive
    end

    it 'returns http unprocessable_entity if position parameters are unprocessable' do
      method(http_method).call :update, params: { album_id: album, id: music_attachment, previous_id: 1, next_id: 2 }
      expect(response).to have_http_status :unprocessable_entity
    end

    it 'allows missing previous_id' do
      next_model = Fabricate(:album_music_attachment, album: album, position: '0.2')

      method(http_method).call :update, params: { album_id: album, id: music_attachment, next_id: next_model.music_attachment_id }

      subject_model = AlbumMusicAttachment.find_by!(album: album, music_attachment: music_attachment)
      expect(subject_model.position).to be < BigDecimal('0.2')
    end

    it 'allows missing next_id' do
      previous_model = Fabricate(:album_music_attachment, album: album, position: '0.1')

      method(http_method).call :update, params: { album_id: album, id: music_attachment, previous_id: previous_model.music_attachment_id }

      subject_model = AlbumMusicAttachment.find_by!(album: album, music_attachment: music_attachment)
      expect(subject_model.position).to be > BigDecimal('0.1')
    end
  end

  describe 'PUT #update' do
    context 'with write scope' do
      before do
        allow(controller).to receive(:doorkeeper_token) do
          Fabricate(:accessible_access_token, resource_owner_id: Fabricate(:user).id, scopes: 'write')
        end
      end

      include_examples 'position update', :put

      it 'creates album music attachments' do
        put :update, params: { album_id: album, id: music_attachment }
        expect { AlbumMusicAttachment.find_by!(album: album, music_attachment: music_attachment) }.not_to raise_error
      end

      it 'returns http success' do
        put :update, params: { album_id: album, id: music_attachment }
        expect(response).to have_http_status :success
      end
    end

    context 'without write scope' do
      it 'returns http unauthorized' do
        put :update, params: { album_id: album, id: music_attachment }
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe 'PATCH #update' do
    context 'with write scope' do
      before do
        allow(controller).to receive(:doorkeeper_token) do
          Fabricate(:accessible_access_token, resource_owner_id: Fabricate(:user).id, scopes: 'write')
        end
      end

#      include_examples 'position update', :patch do
#        before do
#          Fabricate(
#            :album_music_attachment,
#            album: album,
#            music_attachment: music_attachment,
#            position: '0.3',
#          )
#        end
#      end

      it 'updates album music attachments' do
        album_music_attachment = Fabricate(
          :album_music_attachment,
          album: album,
          music_attachment: music_attachment,
          position: '0.1',
        )

        origin = Fabricate(:album_music_attachment, album: album, position: '0.2')

        patch :update, params: { album_id: album.id, id: music_attachment.id, previous_id: origin.music_attachment_id }

        album_music_attachment.reload
        expect(album_music_attachment.position).to be > BigDecimal('0.2')
      end

      it 'returns http success' do
        album_music_attachment = Fabricate(
          :album_music_attachment,
          album: album,
          music_attachment: music_attachment,
          position: '0.1',
        )

        origin = Fabricate(:album_music_attachment, album: album, position: '0.2')

        patch :update, params: { album_id: album.id, id: music_attachment.id, previous_id: origin.music_attachment_id }

        expect(response).to have_http_status :success
      end
    end

    context 'without write scope' do
      it 'returns http unauthorized' do
        album_music_attachment = Fabricate(
          :album_music_attachment,
          album: album,
          music_attachment: music_attachment,
          position: '0.1',
        )

        origin = Fabricate(:album_music_attachment, album: album, position: '0.2')

        patch :update, params: { album_id: album.id, id: music_attachment.id, previous_id: origin.music_attachment_id }

        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:album_music_attachment) do
      Fabricate(
        :album_music_attachment,
        album: album,
        music_attachment: music_attachment,
        position: '0.1',
      )
    end

    context 'with write scope' do
      before do
        allow(controller).to receive(:doorkeeper_token) do
          Fabricate(:accessible_access_token, resource_owner_id: Fabricate(:user).id, scopes: 'write')
        end
      end

      it 'destroys album music attachments' do
        delete :destroy, params: { album_id: album, id: music_attachment }
        expect { album_music_attachment.reload }.to raise_error ActiveRecord::RecordNotFound
      end

      it 'returns http success' do
        delete :destroy, params: { album_id: album, id: music_attachment }
        expect(response).to have_http_status :success
      end
    end

    context 'without write scope' do
      it 'returns http unauthorized' do
        delete :destroy, params: { album_id: album, id: music_attachment }
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe 'GET #index' do
    render_views

    it 'renders music attachments ordered by position column with id constraints' do
      album_music_attachments = [
        Fabricate(:album_music_attachment, album: album, position: '0.3'),
        Fabricate(:album_music_attachment, album: album, position: '0.2'),
        Fabricate(:album_music_attachment, album: album, position: '0.1'),
      ]

      get :index, params: { album_id: album, since_id: album_music_attachments[2].music_attachment_id, max_id: album_music_attachments[0].music_attachment_id }

      expect(body_as_json.pluck(:id)).to match_array [album_music_attachments[1].music_attachment_id]
    end

    it 'renders music attachments ordered by position column with limit constraint' do
      album_music_attachments = [
        Fabricate(:album_music_attachment, album: album, position: '0.2'),
        Fabricate(:album_music_attachment, album: album, position: '0.1'),
      ]

      get :index, params: { album_id: album, limit: 1 }

      expect(body_as_json.pluck(:id)).to match_array [album_music_attachments[1].music_attachment_id]
    end

    it 'set pagination headers if necessary' do
      album_music_attachments = [
        Fabricate(:album_music_attachment, album: album, position: '0.3'),
        Fabricate(:album_music_attachment, album: album, position: '0.2'),
        Fabricate(:album_music_attachment, album: album, position: '0.1'),
      ]

      get :index, params: { album_id: album, since_id: album_music_attachments[2].music_attachment_id, limit: 1 }

      expect(response.headers['Link'].find_link(['rel', 'next']).href).to eq api_v1_album_tracks_url(limit: 1, since_id: album_music_attachments[1].music_attachment_id)
      expect(response.headers['Link'].find_link(['rel', 'prev']).href).to eq api_v1_album_tracks_url(limit: 1, max_id: album_music_attachments[1].music_attachment_id)
    end

    it 'returns http unprocessable_entity if ranging parameters are unprocessable' do
      get :index, params: { album_id: album, since_id: 1, max_id: 2 }
      expect(response).to have_http_status :unprocessable_entity
    end

    it 'returns http success' do
      get :index, params: { album_id: album }
      expect(response).to have_http_status :success
    end
  end
end
