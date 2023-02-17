require 'rails_helper'

RSpec.describe "findingaids/index", type: :view do
  before(:each) do
    assign(:findingaids, [
      Findingaid.create!(
        filename: "Filename",
        content: "",
        md5sum: "Md5sum",
        sha1sum: "Sha1sum",
        slug: "Slug",
        eadid: "Eadid",
        eadurl: "Eadurl",
        state: "State",
        error: "Error"
      ),
      Findingaid.create!(
        filename: "Filename",
        content: "",
        md5sum: "Md5sum",
        sha1sum: "Sha1sum",
        slug: "Slug",
        eadid: "Eadid",
        eadurl: "Eadurl",
        state: "State",
        error: "Error"
      )
    ])
  end

  it "renders a list of findingaids" do
    render
    assert_select "tr>td", text: "Filename".to_s, count: 2
    assert_select "tr>td", text: "".to_s, count: 2
    assert_select "tr>td", text: "Md5sum".to_s, count: 2
    assert_select "tr>td", text: "Sha1sum".to_s, count: 2
    assert_select "tr>td", text: "Slug".to_s, count: 2
    assert_select "tr>td", text: "Eadid".to_s, count: 2
    assert_select "tr>td", text: "Eadurl".to_s, count: 2
    assert_select "tr>td", text: "State".to_s, count: 2
    assert_select "tr>td", text: "Error".to_s, count: 2
  end
end
