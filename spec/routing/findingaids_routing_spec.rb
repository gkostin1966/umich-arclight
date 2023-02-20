require "rails_helper"

RSpec.describe FindingaidsController, pending: "Review", type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/findingaids").to route_to("findingaids#index")
    end

    it "routes to #new" do
      expect(get: "/findingaids/new").to route_to("findingaids#new")
    end

    it "routes to #show" do
      expect(get: "/findingaids/1").to route_to("findingaids#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/findingaids/1/edit").to route_to("findingaids#edit", id: "1")
    end

    it "routes to #create" do
      expect(post: "/findingaids").to route_to("findingaids#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/findingaids/1").to route_to("findingaids#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/findingaids/1").to route_to("findingaids#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/findingaids/1").to route_to("findingaids#destroy", id: "1")
    end
  end
end
