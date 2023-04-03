require 'rails_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe IndexFindingAidJob, type: :job do
  include ActiveJob::TestHelper

  let(:src_path) { 'path/to/file.xml' }
  let(:fd) { StringIO.open(xml) }
  let(:xml) do
    <<~EOS
      <ead>
        <eadheader>
          #{eadid_tag}
        </eadheader>
          <archdesc level="1">
            <did>
              <unittitle>title</unittitle>
            </did>
          </archdesc>
      </ead>
    EOS
  end
  let(:eadid_tag) { "<eadid>#{eadid}</eadid>" }
  let(:eadid) { "eadid.slug" }
  let(:eadid_slug) { "eadid-slug" }
  let(:repo_id) { 'repo' }
  let(:repository) { class_double("Arclight::Repository", "repository", name: "repository") }
  let(:dest_dir) { "#{DulArclight.finding_aid_data}/xml/#{repo_id}" }
  let(:dest_path) { "#{dest_dir}/#{eadid_slug}.xml" }
  let(:err_msg) { "Error Message" }

  before do
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:open).with(src_path, "r:UTF-8:UTF-8").and_yield(fd)
    allow(Arclight::Repository).to receive(:find_by).with(slug: repo_id).and_return(repository)
    allow(FileUtils).to receive(:mkdir_p).with(dest_dir)
    allow(FileUtils).to receive(:copy_file).with(src_path, dest_path, {dereference: true, preserve: true, remove_destination: true})
    allow(IngestAutomationJob).to receive(:perform_later).and_call_original
    allow(IngestAutomationJob).to receive(:perform_later).with('index.success', src_path: src_path, archive_path: dest_path, ead_id: eadid_slug)
    allow(IngestAutomationJob).to receive(:perform_later).with('index.failure', src_path: src_path, archive_path: dest_path, ead_id: eadid_slug, err_msg: err_msg)
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'queues the job' do
    expect { described_class.perform_later(src_path, repo_id) }.to have_enqueued_job(described_class).with(src_path, repo_id).on_queue("index")
  end

  it 'performs the job' do
    expect { perform_enqueued_jobs { described_class.perform_later(src_path, repo_id) } }.not_to raise_exception
    expect(IngestAutomationJob).to have_received(:perform_later).with('index.success', src_path: src_path, archive_path: dest_path, ead_id: eadid_slug)
  end

  it 'copies the source file to data xml repo directory using ead id' do
    perform_enqueued_jobs { described_class.perform_later(src_path, repo_id) }
    expect(FileUtils).to have_received(:mkdir_p).with(dest_dir)
    expect(FileUtils).to have_received(:copy_file).with(src_path, dest_path, {dereference: true, preserve: true, remove_destination: true})
  end

  context 'when eadid tag' do
    let(:err_msg) { /Document is missing mandatory uniqueKey field: id/ }

    context 'when value empty' do
      let(:eadid) { "" }

      it 'raises an exception' do
        expect { described_class.perform_now(src_path, repo_id) }.to raise_exception(DulArclight::IndexError, err_msg)
        expect(IngestAutomationJob).to have_received(:perform_later).with('index.failure', src_path: src_path, archive_path: nil, ead_id: nil, err_msg: err_msg)
      end

      it 'does NOT copy source file to data xml repo directory' do
        expect { described_class.perform_now(src_path, repo_id) }.to raise_exception(DulArclight::IndexError, err_msg)
        expect(FileUtils).not_to have_received(:mkdir_p).with(dest_path)
        expect(FileUtils).not_to have_received(:copy_file).with(src_path, dest_path, {dereference: true, preserve: true, remove_destination: true})
      end
    end

    context 'when tag missing' do
      let(:eadid_tag) { "" }

      it 'raises an exception' do
        expect { described_class.perform_now(src_path, repo_id) }.to raise_exception(DulArclight::IndexError, err_msg)
        expect(IngestAutomationJob).to have_received(:perform_later).with('index.failure', src_path: src_path, archive_path: nil, ead_id: nil, err_msg: err_msg)
      end

      it 'does NOT copy source file to data xml repo directory' do
        expect { described_class.perform_now(src_path, repo_id) }.to raise_exception(DulArclight::IndexError, err_msg)
        expect(FileUtils).not_to have_received(:mkdir_p).with(dest_path)
        expect(FileUtils).not_to have_received(:copy_file).with(src_path, dest_path, {dereference: true, preserve: true, remove_destination: true})
      end
    end
  end

  context 'when missing file' do
    before do
      allow(File).to receive(:open).with(src_path, "r:UTF-8:UTF-8").and_raise(StandardError, err_msg)
    end

    it 'raises an exception' do
      expect { described_class.perform_now(src_path, repo_id) }.to raise_exception(DulArclight::IndexError, err_msg)
      expect(IngestAutomationJob).to have_received(:perform_later).with('index.failure', src_path: src_path, archive_path: nil, ead_id: nil, err_msg: err_msg)
    end

    it 'does NOT copy source file to data xml repo directory' do
      expect { described_class.perform_now(src_path, repo_id) }.to raise_exception(DulArclight::IndexError, err_msg)
      expect(FileUtils).not_to have_received(:mkdir_p).with(dest_path)
      expect(FileUtils).not_to have_received(:copy_file).with(src_path, dest_path, {dereference: true, preserve: true, remove_destination: true})
    end
  end

  context 'when repo nil' do
    let(:repo_id) { nil }
    let(:err_msg) { /no implicit conversion of nil into String/ }

    it 'raises an exception' do
      expect { described_class.perform_now(src_path, repo_id) }.to raise_exception(DulArclight::IndexError, err_msg)
      expect(IngestAutomationJob).to have_received(:perform_later).with('index.failure', src_path: src_path, archive_path: nil, ead_id: eadid_slug, err_msg: err_msg)
    end

    it 'does NOT copy source file to data xml repo directory' do
      expect { described_class.perform_now(src_path, repo_id) }.to raise_exception(DulArclight::IndexError, err_msg)
      expect(FileUtils).not_to have_received(:mkdir_p).with(dest_path)
      expect(FileUtils).not_to have_received(:copy_file).with(src_path, dest_path, {dereference: true, preserve: true, remove_destination: true})
    end
  end

  context 'when missing repo' do
    let(:err_msg) { /undefined method `name' for nil:NilClass/ }

    before do
      allow(Arclight::Repository).to receive(:find_by).with(slug: repo_id).and_return(nil)
    end

    it 'raises an exception' do
      expect { described_class.perform_now(src_path, repo_id) }.to raise_exception(DulArclight::IndexError, err_msg)
      expect(IngestAutomationJob).to have_received(:perform_later).with('index.failure', src_path: src_path, archive_path: nil, ead_id: nil, err_msg: err_msg)
    end

    it 'does NOT copy source file to data xml repo directory' do
      expect { described_class.perform_now(src_path, repo_id) }.to raise_exception(DulArclight::IndexError, err_msg)
      expect(FileUtils).not_to have_received(:mkdir_p).with(dest_path)
      expect(FileUtils).not_to have_received(:copy_file).with(src_path, dest_path, {dereference: true, preserve: true, remove_destination: true})
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
