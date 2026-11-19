# frozen_string_literal: true

module RedmineAvatars
  # Bild entfernen, wenn der Benutzer gelöscht wird
  module UserPatch
    def self.included(base)
      base.after_destroy :remove_avatar_files
    end

    private

    def remove_avatar_files
      Avatar.new(self).remove_files
    end
  end
end
