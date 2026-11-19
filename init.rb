# frozen_string_literal: true

# Avatars – eigene Profilbilder für Redmine
#
# Redmine zeigt Initialen oder Bilder von Gravatar. Dieses Plugin erlaubt
# eigene Bilder, gespeichert auf dem eigenen Server:
#   Mein Konto → Avatar ändern       eigenes Bild hochladen oder entfernen
#   Administration → Benutzer        Bild jedes Benutzers pflegen
# Ohne hochgeladenes Bild bleibt alles wie bei Redmine.

Redmine::Plugin.register :redmine_avatars do
  name 'Avatars'
  author 'stbt.de'
  author_url 'https://stbt.de/'
  description 'Eigene Profilbilder hochladen – gespeichert auf dem eigenen Server, statt Gravatar.'
  version '1.0.0'
  url 'https://github.com/stbt-de/redmine-avatars'
  requires_redmine version_or_higher: '6.0.0'
end

# Hook-Klasse laden (Zeitwerk lädt lib/ nur bei Bedarf), Anzeige der Avatare
# umstellen und Bilder beim Löschen eines Benutzers entfernen
RedmineAvatars::Hooks
AvatarsHelper.prepend(RedmineAvatars::AvatarsHelperPatch) unless AvatarsHelper < RedmineAvatars::AvatarsHelperPatch
User.include(RedmineAvatars::UserPatch) unless User < RedmineAvatars::UserPatch
