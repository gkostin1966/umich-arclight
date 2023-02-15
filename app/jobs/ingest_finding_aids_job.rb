# frozen_string_literal: true

require 'um_arclight/errors'
require 'um_arclight/package/generator'

# Job to queue packaging
class IngestFindingAidsJob < ApplicationJob
  queue_as :ingest

  def perform
    env = { }
    cmd = "rclone bundle exec traject -u #{ENV.fetch('SOLR_URL', Blacklight.default_index.connection.base_uri).to_s.chomp('/')} -i xml -c ./lib/dul_arclight/traject/ead2_config.rb #{path}"

    stdout_and_stderr, process_status = Open3.capture2e(env, cmd)

    if process_status.success?
      puts stdout_and_stderr
    else
      raise DulArclight::IndexError, stdout_and_stderr
    end
  end
end
