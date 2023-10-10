require "test_helper"

describe EpisodeImport do
  let(:import) { create(:episode_import, status: "created") }

  describe "#save" do
    it "updates the podcast_import status" do
      assert import.status_created?
      assert import.podcast_import.status_created?

      import.status_error!
      assert import.podcast_import.status_error?

      import.status_complete!
      assert import.podcast_import.status_complete?

      import.status_importing!
      assert import.podcast_import.status_importing?
    end
  end
end
