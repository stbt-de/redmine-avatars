# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class AvatarsTest < Redmine::IntegrationTest
  include RedmineAvatars::TestHelper

  fixtures :users, :email_addresses, :user_preferences, :roles, :members, :member_roles,
           :projects, :enabled_modules, :trackers, :projects_trackers, :issue_statuses,
           :issues, :enumerations, :journals, :journal_details

  def setup
    reset_avatars
  end

  def teardown
    reset_avatars
  end

  # --- Hochladen -----------------------------------------------------------

  def test_benutzer_laedt_eigenes_bild_hoch
    log_user('jsmith', 'jsmith')
    get '/my/avatar'
    assert_response :success
    assert_select 'form#avatars-form input[type=file][name=file]'

    post '/my/avatar', params: { file: avatar_upload('photo.jpg', 'image/jpeg') }
    assert_redirected_to '/my/avatar'
    assert_equal I18n.t(:notice_avatars_saved, locale: :en), flash[:notice]

    meta = RedmineAvatars::Avatar.new(User.find(2)).current
    assert meta, 'Bild fehlt'
    assert_match(/\A2-\h{16}\.png\z/, meta['filename'])
  end

  def test_bild_wird_quadratisch_auf_256_px_zugeschnitten
    store_avatar(User.find(2), 'photo.jpg', 'image/jpeg')
    avatar = RedmineAvatars::Avatar.new(User.find(2))
    assert_equal [256, 256], png_size(avatar.path(avatar.current))
  end

  def test_kleines_bild_wird_auf_256_px_vergroessert
    store_avatar(User.find(2), 'square.png', 'image/png')
    avatar = RedmineAvatars::Avatar.new(User.find(2))
    assert_equal [256, 256], png_size(avatar.path(avatar.current))
  end

  def test_neues_bild_ersetzt_das_alte
    store_avatar(User.find(2), 'photo.jpg', 'image/jpeg')
    first = RedmineAvatars::Avatar.new(User.find(2)).current
    store_avatar(User.find(2), 'square.png', 'image/png')
    current = RedmineAvatars::Avatar.new(User.find(2)).current

    assert_not_equal first['digest'], current['digest']
    assert_equal 1, Dir.glob(File.join(RedmineAvatars::Avatar.directory, '2-*.png')).size
  end

  def test_svg_wird_abgelehnt
    log_user('jsmith', 'jsmith')
    post '/my/avatar', params: { file: avatar_upload('logo.svg', 'image/svg+xml') }
    assert_equal I18n.t(:error_avatars_type, locale: :en), flash[:error]
    assert_nil RedmineAvatars::Avatar.new(User.find(2)).current
  end

  def test_als_bild_getarnte_html_datei_wird_abgelehnt
    log_user('jsmith', 'jsmith')
    post '/my/avatar', params: { file: avatar_upload('not-an-image.svg', 'image/png') }
    assert_equal I18n.t(:error_avatars_type, locale: :en), flash[:error]
    assert_nil RedmineAvatars::Avatar.new(User.find(2)).current
  end

  def test_ohne_datei_kommt_hinweis
    log_user('jsmith', 'jsmith')
    post '/my/avatar'
    assert_equal I18n.t(:error_avatars_blank, locale: :en), flash[:error]
  end

  def test_benutzer_entfernt_eigenes_bild
    store_avatar(User.find(2))
    log_user('jsmith', 'jsmith')
    delete '/my/avatar'
    assert_redirected_to '/my/avatar'
    assert_nil RedmineAvatars::Avatar.new(User.find(2)).current
    assert_empty Dir.glob(File.join(RedmineAvatars::Avatar.directory, '2-*.png'))
  end

  def test_anonym_kein_hochladen
    get '/my/avatar'
    assert_response :redirect
    assert_match %r{/login}, response.location
  end

  # --- Admin ---------------------------------------------------------------

  def test_admin_pflegt_bild_eines_benutzers
    log_user('admin', 'admin')
    get '/users/2/edit'
    assert_select 'a[href="/users/2/avatar"]'

    get '/users/2/avatar'
    assert_response :success

    post '/users/2/avatar', params: { file: avatar_upload('photo.jpg', 'image/jpeg') }
    assert_redirected_to '/users/2/avatar'
    assert RedmineAvatars::Avatar.new(User.find(2)).current
  end

  def test_ohne_adminrechte_kein_fremdes_bild
    log_user('jsmith', 'jsmith')
    post '/users/3/avatar', params: { file: avatar_upload('photo.jpg', 'image/jpeg') }
    assert_response :forbidden
    assert_nil RedmineAvatars::Avatar.new(User.find(3)).current
  end

  # --- Anzeige -------------------------------------------------------------

  def test_bild_ersetzt_initialen_in_tickets
    with_settings gravatar_enabled: '0' do
      store_avatar(User.find(2))
      log_user('admin', 'admin')
      get '/issues/1'
      assert_response :success
      assert_select 'img.avatar.avatar-image[src^="/avatars/2"]'
    end
  end

  def test_bild_hat_vorrang_vor_gravatar
    with_settings gravatar_enabled: '1' do
      store_avatar(User.find(2))
      log_user('admin', 'admin')
      get '/issues/1'
      assert_select 'img.avatar-image[src^="/avatars/2"]'
    end
  end

  def test_ohne_bild_bleibt_es_bei_initialen
    with_settings gravatar_enabled: '0' do
      log_user('admin', 'admin')
      get '/issues/1'
      assert_select 'img.avatar-image', 0
    end
  end

  def test_mein_konto_verlinkt_auf_hochladen
    log_user('jsmith', 'jsmith')
    get '/my/account'
    assert_select '#content .contextual a[href="/my/avatar"]'
  end

  # --- Auslieferung --------------------------------------------------------

  def test_bild_wird_ausgeliefert
    store_avatar(User.find(2))
    log_user('admin', 'admin')
    get "/avatars/2?v=#{RedmineAvatars::Avatar.new(User.find(2)).current['digest']}"
    assert_response :success
    assert_equal 'image/png', response.media_type
    assert_includes response.headers['Cache-Control'], 'private'
  end

  def test_login_pflicht_gilt_fuer_bilder
    store_avatar(User.find(2))
    with_settings login_required: '1' do
      get '/avatars/2'
      assert_response :redirect
      assert_match %r{/login}, response.location
    end
  end

  def test_ohne_bild_404
    log_user('admin', 'admin')
    get '/avatars/2'
    assert_response :not_found
  end

  # --- Aufräumen -----------------------------------------------------------

  def test_bild_verschwindet_mit_dem_benutzer
    user = User.generate!
    store_avatar(user)
    assert_equal 1, Dir.glob(File.join(RedmineAvatars::Avatar.directory, "#{user.id}-*.png")).size

    user.destroy
    assert_empty Dir.glob(File.join(RedmineAvatars::Avatar.directory, "#{user.id}-*.png"))
  end
end
