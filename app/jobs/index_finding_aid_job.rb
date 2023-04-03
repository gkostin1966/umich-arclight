require 'dul_arclight/errors'
require 'um_arclight/errors'

require_dependency "um_arclight/package/generator"

class IndexFindingAidJob < ApplicationJob
  queue_as :index

  def perform(src_path, repo_id)
    ead_id = nil
    dest_path = nil

    File.open(src_path, "r:UTF-8:UTF-8") do |file|
      # A Traject reader which reads XML, and yields zero to many Nokogiri::XML::Document
      # objects as source records in the traject pipeline. The default is to yield the _entire_ input XML
      # as a single traject source record.
      DulArclight::Traject::DulCompressedReader.new(file, {}).each do |doc|
        indexer = Traject::Indexer::NokogiriIndexer.new(
          # Keep things simple and not interfering with Rails
          "processing_thread_pool" => 0, # disable Indexer processing thread pool
          "solr_writer.thread_pool" => 0, # writing to solr is done inline, no threads
          "solr_writer.batch_size" => 1, # send to solr for each record, no batching
          "solr.url" => ENV.fetch("SOLR_URL", Blacklight.default_index.connection.base_uri).to_s.chomp("/"),
          "repository" => repo_id
        )

        # Note that keys passed in as an initializer arg will "override" any settings set with provide in config.
        indexer.load_config_file(Rails.root.join("lib/dul_arclight/traject/ead2_config.rb"))

        # #process_record takes a single source record, sends it thorough transformation,
        # and sends the output the instance-configured writer. No logging, threading,
        # or error handling is done for you. Skipped records will not be sent to writer.
        # A Traject::Indexer::Context is returned from every call.
        context = indexer.process_record(doc)

        # You can (and may want/need to) manually call indexer.complete to run after_processing steps,
        # and close/flush the writer. After calling complete, the indexer can not be re-used for more process_record calls,
        # as the writer has been closed.
        indexer.complete

        # Make an archive copy of source file available for downloading.
        ead_id = context.output_hash['id']&.first
        dest_dir = File.join(DulArclight.finding_aid_data, "xml", repo_id)
        dest_path = File.join(dest_dir, "#{ead_id}.xml")
        FileUtils.mkdir_p(dest_dir)
        FileUtils.copy_file(src_path, dest_path, preserve: true, dereference: true, remove_destination: true)

        ::IngestAutomationJob.perform_later('index.success', src_path: src_path, archive_path: dest_path, ead_id: ead_id)
      end
    end
  rescue => e
    ::IngestAutomationJob.perform_later('index.failure', src_path: src_path, archive_path: dest_path, ead_id: ead_id, err_msg: e.message)
    raise DulArclight::IndexError, e.message
  end
end
