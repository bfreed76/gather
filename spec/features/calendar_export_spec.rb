require "rails_helper"

feature "calendar export" do
  let!(:user) { create(:user, calendar_token: "xyz") }

  describe "index" do
    before do
      login_as(user, scope: :user)
    end

    scenario do
      visit("/calendars")
      click_on("All Meals")
      expect(page).to have_content("BEGIN:VCALENDAR")
    end
  end

  describe "show" do
    let!(:meal) { create(:meal, head_cook: user) }
    let!(:signup) { create(:signup, meal: meal, household: user.household, adult_meat: 2) }
    let!(:reservation) { create(:reservation, reserver: user) }

    context "with user subdomain" do
      around { |ex| with_user_home_subdomain(user) { ex.run } }

      scenario "your meals" do
        visit("/calendars/meals/xyz.ics")
        expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
          "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Meals You're Attending")

        # Ensure correct subdomain (not https b/c test mode)
        expect(page).to have_content("URL:http://#{user.subdomain}.#{Settings.url.host}")
      end

      scenario "all meals" do
        visit("/calendars/all-meals/xyz.ics")
        expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
          "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:All Meals")
      end

      scenario "community meals" do
        visit("/calendars/community-meals/xyz.ics")
        expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
          "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Meals")
      end

      scenario "jobs" do
        visit("/calendars/shifts/xyz.ics")
        expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
          "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Your Meal Jobs")
      end

      scenario "reservations" do
        visit("/calendars/reservations/xyz.ics")
        expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
          "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Reservations")
      end

      scenario "your reservations" do
        visit("/calendars/your-reservations/xyz.ics")
        expect(page).to have_content("BEGIN:VCALENDAR VERSION:2.0 PRODID:icalendar-ruby "\
          "CALSCALE:GREGORIAN METHOD:PUBLISH X-WR-CALNAME:Your Reservations")
      end

      scenario "bad calendar type" do
        visit("/calendars/pants/xyz.ics")
        expect(page).to have_content("Invalid calendar type")
      end

      scenario "bad token" do
        visit("/calendars/meals/xyzw.ics")
        expect(page).to have_http_status(403)
      end
    end

    context "with apex subdomain" do
      scenario "your meals" do
        visit("/calendars/meals/xyz.ics")
        expect(page).to have_content("Meals You're Attending")

        # We don't want to redirect when fetching ICS in case some clients don't support that.
        expect(current_url).not_to match(user.community.slug)
      end
    end
  end
end
