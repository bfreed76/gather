module Utils
  module FakeData
    class PeopleGenerator < Generator
      attr_accessor :community, :households, :users, :photos

      def initialize(community:, photos: false)
        self.community = community
        self.photos = photos
      end

      def generate
        create_households_and_users
        deactivate_households
      end

      private

      # Creates 24 households (3 inactive) with random vehicles and emergency contacts.
      def create_households_and_users
        self.users = []
        adults = []
        garages = ((1..20).to_a + [nil] * 4).shuffle

        last_names = unique_set(60) { Faker::Name.last_name }

        self.households = 24.times.map do |i|
          dir = resource_path("photos/people/households/#{i.to_s.rjust(2, "0")}/*.jpg")
          joined = Faker::Date.birthday(1, 15)
          last_name = last_names[i]

          adults = Dir[dir].map do |path|
            age = File.basename(path, ".jpg").to_i
            next if age < 16
            bday = Faker::Date.birthday(age, age + 1)
            first_name = Faker::Name.unisex_name

            email = "#{first_name}#{rand(10000000..99999999)}@example.com"

            build(:user,
              fake: true,
              first_name: first_name,
              last_name: bool_prob(70) ? last_name : last_names.pop,
              birthdate: bday,
              email: email,
              google_email: email,
              mobile_phone: Faker::PhoneNumber.simple,
              home_phone: bool_prob(50) ? Faker::PhoneNumber.simple : nil,
              work_phone: bool_prob(15) ? Faker::PhoneNumber.simple : nil,
              joined_on: joined,
              preferred_contact: %w(phone email text).sample,
              photo: photos ? File.open(path) : nil,
              created_at: community.created_at,
              updated_at: community.updated_at
            )
          end.compact

          adults.first.add_role(:work_coordinator) if i < 6
          adults.first.add_role(:admin) if i >= 6 && i < 8

          kids = Dir[dir].map do |path|
            age = File.basename(path, ".jpg").to_i
            next if age >= 16
            bday = Faker::Date.birthday(age, age + 1)
            build(:user, :child,
              fake: true,
              first_name: Faker::Name.unisex_name,
              last_name: bool_prob(90) ? last_name : last_names.pop,
              email: nil,
              google_email: nil,
              mobile_phone: nil,
              guardians: adults,
              birthdate: bday,
              photo: photos ? File.open(path) : nil,
              joined_on: [bday, joined].max,
              created_at: community.created_at,
              updated_at: community.updated_at
            )
          end.compact

          members = adults + kids
          users.concat(members)

          create(:household, :with_vehicles, :with_emerg_contacts, :with_pets,
            name: adults.map(&:last_name).uniq.join("-"),
            community: community,
            unit_num: i + 1,
            garage_nums: garages[i].to_s,
            users: members,
            created_at: community.created_at,
            updated_at: community.updated_at
          )
        end
      end

      # Deactivates 3 households.
      def deactivate_households
        households.shuffle[0...3].each do |h|
          joined = h.users.map(&:joined_on).max
          Timecop.freeze(joined + rand((Date.today - joined).to_i)) do
            h.deactivate
          end
        end
      end
    end
  end
end
