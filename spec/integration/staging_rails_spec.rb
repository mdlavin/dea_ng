require "spec_helper"
require "net/http"

describe "Staging a ruby app", :type => :integration, :requires_warden => true do
  let(:nats) { NatsHelper.new }
  let(:unstaged_url) { "http://localhost:9999/unstaged/rails3_with_db" }
  let(:staged_url) { "http://localhost:9999/staged/rails3_with_db" }
  let(:properties) { {} }
  let(:app_id) { "some-rails-app-id" }
  let(:cleardb_service) do
    valid_service_attributes.merge("label" => "cleardb", "credentials" => { "uri" => "mysql2://some_user:some_password@some-db-provider.com:3306/db_name"})
  end

  let(:staged_responses) do
    nats.send_message("staging", {
        "async" => true,
        "app_id" => app_id,
        "properties" => { "services" => [cleardb_service] },
        "download_uri" => unstaged_url,
        "upload_uri" => staged_url,
        "buildpack_cache_upload_uri" => "http://localhost:9999/buildpack_cache",
        "buildpack_cache_download_uri" => "http://localhost:9999/buildpack_cache"
    }, 2)
  end

  xit "runs a rails 3 app" do
    by "staging the app" do
      puts staged_responses[1]["task_log"]
      expect(staged_responses[1]["detected_buildpack"]).to eq("Ruby/Rails")
      expect(staged_responses[1]["task_log"]).to include("Your bundle is complete!")
      expect(staged_responses[1]["error"]).to be_nil

      download_tgz(staged_url) do |dir|
        expect(Dir.entries("#{dir}/app/vendor")).to include("ruby-1.9.3")
      end
    end

    and_by "starting the app with the correct DATABASE_URL" do
      download_tgz(staged_url) do |dir|
        expect(File.read("#{dir}/startup")).to include('export DATABASE_URL="mysql2://some_user:some_password@some-db-provider.com:3306/db_name"')
      end
    end
  end
end
