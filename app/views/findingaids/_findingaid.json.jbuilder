json.extract! findingaid, :id, :filename, :content, :size, :corpname, :reposlug, :eadid, :eadslug, :eadurl, :state, :error, :created_at, :updated_at
json.url findingaid_url(findingaid, format: :json)
