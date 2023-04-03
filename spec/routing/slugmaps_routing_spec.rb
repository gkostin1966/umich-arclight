require "rails_helper"

RSpec.describe SlugmapsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/slugmaps").to route_to("slugmaps#index")
    end

    it "routes to #new", pending: "Implementation" do
      expect(get: "/slugmaps/new").to route_to("slugmaps#new")
    end

    it "routes to #show", pending: "Implementation" do
      expect(get: "/slugmaps/1").to route_to("slugmaps#show", id: "1")
    end

    it "routes to #edit", pending: "Implementation" do
      expect(get: "/slugmaps/1/edit").to route_to("slugmaps#edit", id: "1")
    end

    it "routes to #create", pending: "Implementation" do
      expect(post: "/slugmaps").to route_to("slugmaps#create")
    end

    it "routes to #update via PUT", pending: "Implementation" do
      expect(put: "/slugmaps/1").to route_to("slugmaps#update", id: "1")
    end

    it "routes to #update via PATCH", pending: "Implementation" do
      expect(patch: "/slugmaps/1").to route_to("slugmaps#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/slugmaps/1").to route_to("slugmaps#destroy", id: "1")
    end
  end
end
