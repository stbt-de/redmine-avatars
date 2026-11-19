# frozen_string_literal: true

require File.expand_path('../../../test/test_helper', __dir__)

module RedmineAvatars
  module TestHelper
    FILES = File.expand_path('fixtures/files', __dir__)

    def avatar_upload(name, type)
      Rack::Test::UploadedFile.new(File.join(FILES, name), type)
    end

    def reset_avatars
      User.find_each do |user|
        next unless user.pref[:avatar]

        user.pref[:avatar] = nil
        user.pref.save!
      end
      FileUtils.rm_rf(RedmineAvatars::Avatar.directory)
    end

    def store_avatar(user, name = 'photo.jpg', type = 'image/jpeg')
      RedmineAvatars::Avatar.new(user).store!(avatar_upload(name, type))
    end

    # Breite und Höhe aus dem PNG-Kopf (IHDR)
    def png_size(path)
      header = File.binread(path, 24)
      header[16, 8].unpack('NN')
    end
  end
end
