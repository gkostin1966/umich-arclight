require 'rails_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe IngestFindingAidJob, type: :job do
  include ActiveJob::TestHelper

  let(:id) { 'id' }
  let(:findingaid) { instance_double("Findingaid", "findingaid", id: 1, content: "", reposlug: "reposlug", eadslug: "eadslug", state: "uploaded", error: nil) }
  let(:path) { File.join(ENV["FINDING_AID_DATA"], "findingaids", findingaid.id.to_s) }
  let(:repository) { instance_double(Blacklight.repository_class, "repository") }
  let(:catalog_controller) { instance_double("CatalogController", "catalog_controller", helpers: helpers) }
  let(:helpers) { double("helpers", blacklight_config: "blacklight_config") } # rubocop:disable RSpec/VerifiedDoubles
  let(:response) { instance_double("Blacklight::Solr::Response", "response", documents: [document]) }
  let(:document) { instance_double("SolrDocument", "document") }

  before do
    allow(Findingaid).to receive(:find).with(id).and_return(findingaid)
    allow(findingaid).to receive(:state=)
    allow(findingaid).to receive(:save!).and_return(true)
    allow(findingaid).to receive(:eadurl=)
    allow(findingaid).to receive(:eadurl).and_return("title")
    allow(IndexFindingAidJob).to receive(:perform_now).with(path, findingaid.reposlug).and_return(true)
    allow(Blacklight.repository_class).to receive(:new).with("blacklight_config").and_return(repository)
    allow(repository).to receive(:search).with({fl: "*", q: ["id:eadslug"], rows: 1, start: 0}).and_return(response)
    allow(CatalogController).to receive(:new).and_return(catalog_controller)
    allow(document).to receive(:[]).with("title_ssm").and_return(["title"])
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'queues the job' do
    expect { described_class.perform_later(id) }.to have_enqueued_job(described_class).with(id).on_queue("index")
  end

  it 'performs the job' do
    expect { perform_enqueued_jobs { described_class.perform_later(id) } }.not_to raise_exception
    expect(IndexFindingAidJob).to have_received(:perform_now).with(path, findingaid.reposlug)
    expect(findingaid).to have_received(:state=).with("indexing")
    expect(findingaid).to have_received(:eadurl=).with("title")
    expect(findingaid).to have_received(:state=).with("indexed")
    expect(findingaid).to have_received(:save!).twice
  end

  context 'when id not found' do
    before { allow(Findingaid).to receive(:find).with(id).and_call_original }

    it 'raises and exception' do
      expect { described_class.perform_now(id) }.to raise_exception(ActiveRecord::RecordNotFound, "Couldn't find Findingaid with 'id'=#{id}")
      expect(findingaid).not_to have_received(:state=).with("indexing")
      expect(IndexFindingAidJob).not_to have_received(:perform_now).with(path, findingaid.reposlug)
    end
  end

  context 'when index finding aid job fails' do
    let(:error_message) { 'error message' }

    before do
      allow(IndexFindingAidJob).to receive(:perform_now).with(path, findingaid.reposlug).and_raise(error_message)
      allow(findingaid).to receive(:error=)
    end

    it 'returns error with message' do
      expect { described_class.perform_now(id) }.not_to raise_exception
      expect(IndexFindingAidJob).to have_received(:perform_now).with(path, findingaid.reposlug)
      expect(findingaid).to have_received(:state=).with("indexing")
      expect(findingaid).to have_received(:error=).with("ERROR: IndexFindAidJob.perform_now(#{path}, #{findingaid.reposlug}) #{error_message}")
      expect(findingaid).to have_received(:state=).with("errored")
      expect(findingaid).to have_received(:save!).twice
    end
  end

  context 'when repository search returns empty documents array' do
    let(:response) { instance_double("Blacklight::Solr::Response", "response", documents: []) }

    before do
      allow(findingaid).to receive(:error=)
    end

    it 'returns error with message' do
      expect { described_class.perform_now(id) }.not_to raise_exception
      expect(IndexFindingAidJob).to have_received(:perform_now).with(path, findingaid.reposlug)
      expect(findingaid).to have_received(:state=).with("indexing")
      expect(findingaid).to have_received(:error=).with("ERROR: fetch_doc(#{findingaid.eadslug}) returned nil!")
      expect(findingaid).to have_received(:state=).with("errored")
      expect(findingaid).to have_received(:save!).twice
    end
  end

  context 'when document title empty' do
    before do
      allow(document).to receive(:[]).with("title_ssm").and_return([""])
      allow(findingaid).to receive(:eadurl).and_return("")
      allow(findingaid).to receive(:error=)
    end

    # rubocop:disable RSpec/MultipleExpectations
    it 'returns error with message' do
      expect { described_class.perform_now(id) }.not_to raise_exception
      expect(IndexFindingAidJob).to have_received(:perform_now).with(path, findingaid.reposlug)
      expect(findingaid).to have_received(:state=).with("indexing")
      expect(findingaid).to have_received(:eadurl=).with("")
      expect(findingaid).to have_received(:error=).with("ERROR: document['title_ssm']&.first is blank!")
      expect(findingaid).to have_received(:state=).with("errored")
      expect(findingaid).to have_received(:save!).twice
    end
    # rubocop:enable RSpec/MultipleExpectations
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
