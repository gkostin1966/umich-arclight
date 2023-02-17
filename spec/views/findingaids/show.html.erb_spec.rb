require 'rails_helper'

RSpec.describe "findingaids/show", type: :view do
  before(:each) do
    @findingaid = assign(:findingaid, Findingaid.create!(
      filename: "Filename",
      content: "",
      md5sum: "Md5sum",
      sha1sum: "Sha1sum",
      slug: "Slug",
      eadid: "Eadid",
      eadurl: "Eadurl",
      state: "State",
      error: "Error"
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Filename/)
    expect(rendered).to match(//)
    expect(rendered).to match(/Md5sum/)
    expect(rendered).to match(/Sha1sum/)
    expect(rendered).to match(/Slug/)
    expect(rendered).to match(/Eadid/)
    expect(rendered).to match(/Eadurl/)
    expect(rendered).to match(/State/)
    expect(rendered).to match(/Error/)
  end
end
