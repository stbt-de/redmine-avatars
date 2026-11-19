# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'tmpdir'
require 'timeout'

module RedmineAvatars
  # Das Profilbild eines Benutzers.
  #
  # Die Datei liegt im Redmine-Dateiverzeichnis (files/redmine_avatars), damit
  # sie mit den Anhängen gesichert wird; die Beschreibung (Dateiname,
  # Prüfsumme) steht in den Einstellungen des Benutzers (UserPreference).
  # Hochgeladene Bilder werden quadratisch zugeschnitten und als PNG mit
  # SIZE × SIZE Pixeln gespeichert; Metadaten (z. B. GPS aus Fotos) fallen weg.
  class Avatar
    ALLOWED_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
    MAX_SIZE = 5 * 1024 * 1024
    SIZE = 256

    # Ungültiger Upload; reason ist ein Symbol für die Fehlermeldung
    class InvalidUpload < StandardError
      attr_reader :reason

      def initialize(reason)
        @reason = reason
        super(reason.to_s)
      end
    end

    def self.directory
      File.join(Attachment.storage_path, 'redmine_avatars')
    end

    def self.convert_bin
      Redmine::Thumbnail::CONVERT_BIN
    end

    attr_reader :user

    def initialize(user)
      @user = user
    end

    # Beschreibung des Bildes oder nil (auch wenn die Datei fehlt)
    def current
      return nil unless user.is_a?(User) && !user.is_a?(AnonymousUser) && user.id

      meta = user.pref[:avatar]
      return nil unless meta.is_a?(Hash) && meta['filename'].present?
      return nil unless File.file?(path(meta))

      meta
    end

    def path(meta)
      File.join(self.class.directory, File.basename(meta['filename']))
    end

    def store!(upload)
      raise InvalidUpload, :blank unless upload.respond_to?(:read) && upload.respond_to?(:original_filename)
      raise InvalidUpload, :too_large if upload.size > MAX_SIZE

      # Binär behandeln, damit auch im Textmodus gelesene Dateien gehen
      data = upload.read.to_s.b
      raise InvalidUpload, :blank if data.empty?

      # Typ nach Inhalt, nicht nach Dateiname; ImageMagick bekommt nur
      # erlaubte Rasterformate zu sehen
      content_type = Marcel::MimeType.for(StringIO.new(data), name: upload.original_filename)
      raise InvalidUpload, :type unless ALLOWED_TYPES.include?(content_type)

      png = process(data, content_type)
      digest = Digest::SHA256.hexdigest(png)[0, 16]
      filename = "#{user.id}-#{digest}.png"

      FileUtils.mkdir_p(self.class.directory)
      remove_files
      File.binwrite(File.join(self.class.directory, filename), png)

      user.pref[:avatar] = { 'filename' => filename, 'digest' => digest }
      user.pref.save!
    end

    def remove!
      remove_files
      return unless user.pref[:avatar]

      user.pref[:avatar] = nil
      user.pref.save!
    end

    # Datei(en) des Benutzers löschen, ohne die Einstellungen anzufassen
    # (beim Löschen des Benutzers)
    def remove_files
      return unless user.id

      Dir.glob(File.join(self.class.directory, "#{user.id}-*.png")).each { |file| FileUtils.rm_f(file) }
    end

    private

    # Quadratisch zuschneiden (Mitte), auf SIZE verkleinern, als PNG ohne
    # Metadaten. Bei GIF nur das erste Bild.
    def process(data, content_type)
      Dir.mktmpdir('redmine_avatars') do |dir|
        source = File.join(dir, 'source')
        target = File.join(dir, 'avatar.png')
        File.binwrite(source, data)

        input = content_type == 'image/gif' ? "#{source}[0]" : source
        command = [
          self.class.convert_bin, input,
          '-auto-orient', '-strip',
          '-thumbnail', "#{SIZE}x#{SIZE}^",
          '-gravity', 'center', '-extent', "#{SIZE}x#{SIZE}",
          "png:#{target}"
        ]
        raise InvalidUpload, :processing unless run(command) && File.file?(target)

        File.binread(target)
      end
    end

    # ImageMagick ohne Shell starten, mit Redmines Zeitlimit für Vorschaubilder
    def run(command)
      pid = Process.spawn(*command, out: File::NULL, err: File::NULL)
      Timeout.timeout(Redmine::Configuration['thumbnails_generation_timeout'].to_i) do
        _, status = Process.wait2(pid)
        status.success?
      end
    rescue Timeout::Error
      Process.kill('KILL', pid)
      Process.detach(pid)
      false
    rescue SystemCallError
      false
    end
  end
end
