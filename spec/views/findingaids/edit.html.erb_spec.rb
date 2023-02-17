require 'rails_helper'

RSpec.describe "findingaids/edit", type: :view do
  before(:each) do
    @findingaid = assign(:findingaid, Findingaid.create!(
      filename: "MyString",
      content: "",
      md5sum: "MyString",
      sha1sum: "MyString",
      slug: "MyString",
      eadid: "MyString",
      eadurl: "MyString",
      state: "MyString",
      error: "MyString"
    ))
  end

  it "renders the edit findingaid form" do
    render

    assert_select "form[action=?][method=?]", findingaid_path(@findingaid), "post" do

      assert_select "input[name=?]", "findingaid[filename]"

      assert_select "input[name=?]", "findingaid[content]"

      assert_select "input[name=?]", "findingaid[md5sum]"

      assert_select "input[name=?]", "findingaid[sha1sum]"

      assert_select "input[name=?]", "findingaid[slug]"

      assert_select "input[name=?]", "findingaid[eadid]"

      assert_select "input[name=?]", "findingaid[eadurl]"

      assert_select "input[name=?]", "findingaid[state]"

      assert_select "input[name=?]", "findingaid[error]"
    end
  end
end
