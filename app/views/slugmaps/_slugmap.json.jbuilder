json.extract! slugmap, :id, :corpname, :reponame, :reposlug, :created_at, :updated_at
json.url slugmap_url(slugmap, format: :json)
