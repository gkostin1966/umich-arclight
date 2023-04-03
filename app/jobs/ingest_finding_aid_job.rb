class IngestFindingAidJob < ApplicationJob
  queue_as :index

  def perform(id)
    findingaid = Findingaid.find(id)
    findingaid.state = "indexing"
    findingaid.save!

    begin
      path = File.join(ENV["FINDING_AID_DATA"], "findingaids", findingaid.id.to_s)
      logger.info "Beginning Finding Aid ingest to repository '#{findingaid.reposlug}' of EAD file #{path}"
      IndexFindingAidJob.perform_now(path, findingaid.reposlug)
    rescue => e
      findingaid.error = "ERROR: IndexFindAidJob.perform_now(#{path}, #{findingaid.reposlug}) #{e.message}"
      findingaid.state = "errored"
    end

    if findingaid.error.blank?
      document = fetch_doc(findingaid.eadslug)
      if document.present?
        findingaid.eadurl = document['title_ssm']&.first
        if findingaid.eadurl.present?
          findingaid.state = "indexed"
        else
          findingaid.error = "ERROR: document['title_ssm']&.first is blank!"
          findingaid.state = "errored"
        end
      else
        findingaid.error = "ERROR: fetch_doc(#{findingaid.eadslug}) returned nil!"
        findingaid.state = "errored"
      end
    end

    findingaid.save!
  end

  private

  def fetch_doc(id)
    params = {
      fl: '*',
      q: ["id:#{id}"],
      start: 0,
      rows: 1
    }
    repo = Blacklight.repository_class.new(CatalogController.new.helpers.blacklight_config)
    response = repo.search(params)
    response.documents.first
  end
end
