# frozen_string_literal: true

# Bild eines Benutzers (für alle, die den Benutzer sehen dürfen)
get 'avatars/:id', to: 'user_avatars#show', as: 'user_avatar', constraints: { id: /\d+/ }

# Eigenes Bild
get 'my/avatar', to: 'user_avatars#edit', as: 'my_avatar'
post 'my/avatar', to: 'user_avatars#update'
delete 'my/avatar', to: 'user_avatars#destroy'

# Bild eines Benutzers durch Admins
get 'users/:user_id/avatar', to: 'user_avatars#edit', as: 'user_avatar_edit', constraints: { user_id: /\d+/ }
post 'users/:user_id/avatar', to: 'user_avatars#update', constraints: { user_id: /\d+/ }
delete 'users/:user_id/avatar', to: 'user_avatars#destroy', constraints: { user_id: /\d+/ }
