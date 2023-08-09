require 'arclight'
require 'arclight/repository'

# Read the repository configuration
repo_config = YAML.safe_load(File.read('./config/repositories.yml'))

namespace :arclight do
  desc 'Greg Kostin'
  task gkostin: :environment do
    puts "Deleting ..."
    ARC_84_EADID_MAP.keys.each do |eadid|
      puts "#{eadid}"
      Blacklight.default_index.connection.delete_by_query("parent_ssim:#{eadid}")
    end
    Blacklight.default_index.connection.commit
    puts "... deleted."
  end
end
