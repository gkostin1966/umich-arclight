require 'dul_arclight/errors'
require 'um_arclight/errors'

require_dependency "um_arclight/package/generator"

class IndexFindingAidJob < ApplicationJob
  queue_as :index

  def perform(path, repo_id)
    env = { 'REPOSITORY_ID' => repo_id }
    cmd = "bundle exec traject -u #{ENV.fetch('SOLR_URL', Blacklight.default_index.connection.base_uri).to_s.chomp('/')} -i xml -c ./lib/dul_arclight/traject/ead2_config.rb #{path}"

    stdout_and_stderr, process_status = Open3.capture2e(env, cmd)

    if process_status.success?
      ead_id = eadid_slug(path)
      dest_path = File.join(DulArclight.finding_aid_data, "xml", repo_id)
      FileUtils.mkdir_p(dest_path)
      dest = File.join(dest_path, "#{ead_id}.xml")
      FileUtils.copy_file(path, dest, preserve: true, dereference: true, remove_destination: true)
      puts stdout_and_stderr
      ::IngestAutomationJob.perform_later('index.success', src_path: path, archive_path: dest, ead_id: ead_id)
    else
      ::IngestAutomationJob.perform_later('index.failure', src_path: path, archive_path: dest, ead_id: ead_id)
      raise DulArclight::IndexError, stdout_and_stderr
    end
  end

  private

  def eadid_slug(path)
    basename = File.basename(path, ".*")
    eadid_slug = nil
    File.open(path, "r:UTF-8:UTF-8") do |f|
      doc = Nokogiri::XML(f)
      eadid_node = doc.at_xpath('/ead/eadheader/eadid')
      eadid_slug = eadid_node.text.strip.tr(".", "-").to_s if eadid_node && eadid_node.text.present?
    end
    eadid_slug || basename
  end
end
