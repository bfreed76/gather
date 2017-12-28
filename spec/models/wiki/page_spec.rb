require "rails_helper"

describe Wiki::Page do
  describe "slug" do
    it "gets set automatically" do
      page = create(:wiki_page, title: "An Excéllent Page")
      expect(page.slug).to eq "an-excellent-page"
    end

    it "gets set properly for home page" do
      page = create(:wiki_page, title: "An Excéllent Page", home: true)
      expect(page.slug).to eq "home"
    end

    it "avoids duplicates" do
      page1 = create(:wiki_page, title: "An Excéllent Page")
      page2 = create(:wiki_page, title: "An Excellent Page")
      page3 = create(:wiki_page, title: "An Éxcellent Page")
      expect(page1.slug).to eq "an-excellent-page"
      expect(page2.slug).to eq "an-excellent-page2"
      expect(page3.slug).to eq "an-excellent-page3"
    end

    it "raises validation if title would give result in reserved slug" do
      Wiki::Page::RESERVED_SLUGS.each do |slug|
        page = build(:wiki_page, title: slug.capitalize)
        expect(page).not_to be_valid
        expect(page.errors[:title].join).to match /This title is a special reserved word or phrase./
      end
    end
  end

  describe "saving versions" do
    let!(:page) { create(:wiki_page) }

    context "with content change" do
      it "saves new version" do
        expect { page.update!(content: "Some new content") }.to change { Wiki::PageVersion.count }.by(1)
      end
    end

    context "with comment" do
      it "saves new version" do
        expect { page.update!(comment: "Some comment") }.to change { Wiki::PageVersion.count }.by(1)
      end
    end

    context "with title change" do
      it "saves new version" do
        expect { page.update!(title: "New title") }.to change { Wiki::PageVersion.count }.by(1)
      end
    end

    context "without title, content, or comment change" do
      it "doesn't save new version" do
        expect { page.update!(editable_by: "wikiist") }.to change { Wiki::PageVersion.count }.by(0)
        expect { page.update!(data_source: "http://foo.com") }.to change { Wiki::PageVersion.count }.by(0)
      end
    end
  end
end
