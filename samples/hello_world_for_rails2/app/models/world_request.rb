class WorldRequest < ActionWebService::Struct
  member :world_id, :int
  member :message, :string
end
