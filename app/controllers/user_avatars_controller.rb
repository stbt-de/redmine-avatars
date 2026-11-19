# frozen_string_literal: true

# Profilbilder: ausliefern, hochladen, entfernen.
#
#   /avatars/:id            Bild – nur für angemeldete bzw. berechtigte
#                           Benutzer (Redmines Login-Pflicht gilt)
#   /my/avatar              eigenes Bild
#   /users/:user_id/avatar  Bild eines Benutzers (nur Admins)
class UserAvatarsController < ApplicationController
  self.main_menu = false

  before_action :find_user_for_show, only: :show
  before_action :find_user_for_edit, except: :show

  def show
    meta = RedmineAvatars::Avatar.new(@user).current
    return head(:not_found) unless meta

    # Nur im Browser zwischenspeichern, nicht in geteilten Caches
    if params[:v] == meta['digest']
      expires_in 1.year, public: false
    else
      expires_now
    end
    response.headers['X-Content-Type-Options'] = 'nosniff'

    send_file RedmineAvatars::Avatar.new(@user).path(meta), type: 'image/png', disposition: 'inline'
  end

  def edit
    @avatar = RedmineAvatars::Avatar.new(@user).current
    render layout: (@own ? 'base' : 'admin')
  end

  def update
    begin
      RedmineAvatars::Avatar.new(@user).store!(params[:file])
      flash[:notice] = l(:notice_avatars_saved)
    rescue RedmineAvatars::Avatar::InvalidUpload => e
      flash[:error] = l(:"error_avatars_#{e.reason}")
    end
    redirect_to edit_path
  end

  def destroy
    RedmineAvatars::Avatar.new(@user).remove!
    flash[:notice] = l(:notice_avatars_removed)
    redirect_to edit_path
  end

  private

  def find_user_for_show
    @user = User.active.find_by(id: params[:id])
    render_404 unless @user&.visible?
  end

  # Eigenes Bild: angemeldet sein. Fremdes Bild: Admin.
  def find_user_for_edit
    if params[:user_id]
      require_admin || return
      @user = User.find_by(id: params[:user_id])
      return render_404 unless @user

      @own = (@user == User.current)
    else
      require_login || return
      @user = User.current
      @own = true
    end
  end

  def edit_path
    params[:user_id] ? user_avatar_edit_path(@user) : my_avatar_path
  end
end
