# frozen_string_literal: true

module RedmineAvatars
  # Links zum Hochladen:
  #   Mein Konto              "Avatar ändern" oben in den Aktionen
  #   Benutzer bearbeiten     Zeile "Avatar" mit Link (nur Admins)
  class Hooks < Redmine::Hook::ViewListener
    def view_my_account_contextual(context = {})
      link_to(sprite_icon('user', l(:button_avatars_change)), context[:controller].my_avatar_path,
              class: 'icon icon-user')
    end

    def view_users_form(context = {})
      user = context[:user]
      return '' unless User.current.admin? && user.is_a?(User) && user.persisted?

      controller = context[:controller]
      content_tag(:p) do
        content_tag(:label, l(:label_avatars_avatar)) +
          link_to(l(:button_avatars_change), controller.user_avatar_edit_path(user))
      end
    end
  end
end
