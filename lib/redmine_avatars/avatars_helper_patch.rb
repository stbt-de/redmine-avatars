# frozen_string_literal: true

module RedmineAvatars
  # Wird AvatarsHelper vorangestellt (init.rb): hat ein Benutzer ein eigenes
  # Bild, erscheint es überall, wo Redmine einen Avatar zeigt (Tickets,
  # Listen, Beobachter, Kopf …). Ohne Bild bleibt es bei Redmines Initialen
  # bzw. Gravatar.
  module AvatarsHelperPatch
    def avatar(user, options = {})
      meta = user.is_a?(User) ? Avatar.new(user).current : nil
      return super unless meta

      options = options.dup
      size = (options.delete(:size) || GravatarHelper::DEFAULT_OPTIONS[:size]).to_i
      css_class = ['avatar', 'avatar-image', "s#{size}", options.delete(:class)].compact.join(' ')
      title = options.delete(:title) || user.name

      image_tag(user_avatar_path(user, v: meta['digest']),
                alt: '', title: title, class: css_class, width: size, height: size, loading: 'lazy')
    end

    # Mein Konto: Klick auf den Avatar führt zum Hochladen (statt zu Gravatar)
    def avatar_edit_link(user, options = {})
      return super unless user == User.current && user.logged?

      link_to(avatar(user, { title: l(:button_avatars_change) }.merge(options)), my_avatar_path)
    end
  end
end
