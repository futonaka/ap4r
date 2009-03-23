# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_hoge_session',
  :secret      => '174995b4a72cbcc76734452d00a9ed5a4a6ae4c2803a11013eb6597ac3455235fe3d64c3eccaa676efe4ce0e5ff741b7603ea82aa5bcb1da0e5e13801a6d4424'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
