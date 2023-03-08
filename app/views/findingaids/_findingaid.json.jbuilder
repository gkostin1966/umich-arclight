json.extract! findingaid, :id, :filename, :content, :md5sum, :sha1sum, :slug, :eadid, :eadurl, :state, :error, :created_at, :updated_at
json.url findingaid_url(findingaid, format: :json)
