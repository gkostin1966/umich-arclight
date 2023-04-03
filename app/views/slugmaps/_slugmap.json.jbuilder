json.extract! slugmap, :id, :corpname, :reposlug, :created_at, :updated_at
json.url slugmap_url(slugmap, format: :json)
