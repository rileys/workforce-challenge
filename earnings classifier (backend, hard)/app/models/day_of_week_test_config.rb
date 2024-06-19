class DayOfWeekTestConfig < ApplicationRecord
  ##
  # Contains the configuration of a day of week test
  #

  enum wday: { sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6 }
  belongs_to :day_of_week_test
  validates :wday, presence: true
end
