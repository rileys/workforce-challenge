require 'test_helper'

class EarningsClassifierTest < ActiveSupport::TestCase
  setup do
    # regular hours rule (applies by default)
    HoursRule.create!(code: "REGULAR_HOURS", hours_rule_config: HoursRuleConfig.new(rank: 0))

    # timesheet overtime rule (applies after 40 hours in a timesheet)
    HoursRule.create!(code: "OVERTIME",
      hours_rule_config: HoursRuleConfig.new(rank: 1),
      earning_tests: [
        MaximumHoursTest.new(maximum_hours_test_config: MaximumHoursTestConfig.new(period: "timesheet", threshold: 40))
      ]
    )

    # rule for Saturday hours
    HoursRule.create!(
      code: "SATURDAY",
      hours_rule_config: HoursRuleConfig.new(rank: 2),
      earning_tests: [
        DayOfWeekTest.new(day_of_week_test_config: DayOfWeekTestConfig.new(wday: 'saturday'))
      ]
    )

    # rule for Sunday hours
    HoursRule.create!(
      code: "SUNDAY",
      hours_rule_config: HoursRuleConfig.new(rank: 2),
      earning_tests: [
        DayOfWeekTest.new(day_of_week_test_config: DayOfWeekTestConfig.new(wday: 'sunday'))
      ]
    )

    # shift overtime rule (applies after 12 hours in a shift)
    HoursRule.create!(
      code: "DOUBLE_TIME",
      hours_rule_config: HoursRuleConfig.new(rank: 3),
      earning_tests: [
        MaximumHoursTest.new(maximum_hours_test_config: MaximumHoursTestConfig.new(period: "shift", threshold: 12))
      ]
    )

    # an addon that applies to shifts of 10hrs or more
    AddonRule.create!(
      code: "MEAL_ALLOWANCE",
      addon_rule_config: AddonRuleConfig.new(units: 1),
      earning_tests: [
        MaximumHoursTest.new(maximum_hours_test_config: MaximumHoursTestConfig.new(period: "shift", threshold: 10))
      ]
    )
  end

  test "regular hours" do
    date = Time.zone.today.prev_occurring(:monday)

    timesheet = Timesheet.create!(start: date.beginning_of_week, finish: date.end_of_week)

    timesheet.shifts.create!(start:  date.in(9.hours), finish: date.in(17.hours)) # 9am -> 5pm

    EarningsClassifier.new(timesheet).record!

    expected = <<~EXPECT.strip
      REGULAR_HOURS,8.0
    EXPECT

    assert_earnings expected, timesheet
  end

  test "multiple regular hours" do
    date1 = Time.zone.today.prev_occurring(:monday)
    date2 = Time.zone.today.prev_occurring(:monday).next_day

    timesheet = Timesheet.create!(start: date1.beginning_of_week, finish: date1.end_of_week.advance(weeks: 1))

    timesheet.shifts.create!(start:  date1.in(9.hours), finish: date1.in(17.hours)) # 9am -> 5pm
    timesheet.shifts.create!(start:  date2.in(9.hours), finish: date2.in(17.hours)) # 9am -> 5pm

    EarningsClassifier.new(timesheet).record!

    expected = <<~EXPECT.strip
      REGULAR_HOURS,16.0
    EXPECT

    assert_earnings expected, timesheet
  end

  test "regular hours and meal addon" do
    date = Time.zone.today.prev_occurring(:monday)

    timesheet = Timesheet.create!(start: date.beginning_of_week, finish: date.end_of_week)

    timesheet.shifts.create!(start: date.in(8.hours), finish: date.in(20.hours)) # 8am -> 8pm

    EarningsClassifier.new(timesheet).record!

    expected = <<~EXPECT.strip
      REGULAR_HOURS,12.0
      MEAL_ALLOWANCE,1.0
    EXPECT

    assert_earnings expected, timesheet
  end

  test "regular hours and double time" do
    date = Time.zone.today.prev_occurring(:monday)

    timesheet = Timesheet.create!(start: date.beginning_of_week, finish: date.end_of_week)

    timesheet.shifts.create!(start: date.in(6.hours), finish: date.in(19.hours)) # 6am -> 7pm

    EarningsClassifier.new(timesheet).record!

    expected = <<~EXPECT.strip
      DOUBLE_TIME,1.0
      REGULAR_HOURS,12.0
      MEAL_ALLOWANCE,1.0
    EXPECT

    assert_earnings expected, timesheet
  end

  test "regular hours and overtime" do
    date1 = Time.zone.today.prev_occurring(:monday)
    date2 = Time.zone.today.prev_occurring(:monday).advance(days: 1)
    date3 = Time.zone.today.prev_occurring(:monday).advance(days: 2)
    date4 = Time.zone.today.prev_occurring(:monday).advance(days: 3)
    date5 = Time.zone.today.prev_occurring(:monday).advance(days: 4)

    timesheet = Timesheet.create!(start: date1.beginning_of_week, finish: date1.end_of_week.advance(weeks: 1))

    timesheet.shifts.create!(start: date1.in(9.hours), finish: date1.in(18.hours)) # 9am -> 6pm
    timesheet.shifts.create!(start: date2.in(9.hours), finish: date2.in(18.hours)) # 9am -> 6pm
    timesheet.shifts.create!(start: date3.in(9.hours), finish: date3.in(18.hours)) # 9am -> 6pm
    timesheet.shifts.create!(start: date4.in(9.hours), finish: date4.in(18.hours)) # 9am -> 6pm
    timesheet.shifts.create!(start: date5.in(9.hours), finish: date5.in(18.hours)) # 9am -> 6pm

    EarningsClassifier.new(timesheet).record!

    expected = <<~EXPECT.strip
      OVERTIME,5.0
      REGULAR_HOURS,40.0
    EXPECT

    assert_earnings expected, timesheet
  end

  test "regular hours, double time, overtime, and meal addon" do
    date1 = Time.zone.today.prev_occurring(:monday)
    date2 = Time.zone.today.prev_occurring(:monday).advance(days: 1)
    date3 = Time.zone.today.prev_occurring(:monday).advance(days: 2)
    date4 = Time.zone.today.prev_occurring(:monday).advance(days: 3)
    date5 = Time.zone.today.prev_occurring(:monday).advance(days: 4)

    timesheet = Timesheet.create!(start: date1.beginning_of_week, finish: date1.end_of_week.advance(weeks: 1))

    timesheet.shifts.create!(start: date1.in(9.hours), finish: date1.in(18.hours)) # 9am -> 6pm
    timesheet.shifts.create!(start: date2.in(7.hours), finish: date2.in(21.hours)) # 7am -> 9pm
    timesheet.shifts.create!(start: date3.in(9.hours), finish: date3.in(18.hours)) # 9am -> 6pm
    timesheet.shifts.create!(start: date4.in(9.hours), finish: date4.in(18.hours)) # 9am -> 6pm

    EarningsClassifier.new(timesheet).record!

    expected = <<~EXPECT.strip
      OVERTIME,1.0
      REGULAR_HOURS,38.0
      DOUBLE_TIME,2.0
      MEAL_ALLOWANCE,1.0
    EXPECT

    assert_earnings expected, timesheet
  end

  test "saturday" do
    saturday = Time.zone.today.prev_occurring(:saturday)
    timesheet = Timesheet.create!(start: saturday.beginning_of_week, finish: saturday.end_of_week)
    timesheet.shifts.create!(start: saturday.in(9.hours), finish: saturday.in(18.hours)) # 9am -> 6pm

    EarningsClassifier.new(timesheet).record!

    expected = <<~EXPECT.strip
      SATURDAY,9.0
    EXPECT
    assert_earnings expected, timesheet
  end

   test "sunday" do
    sunday = Time.zone.today.prev_occurring(:sunday)
    timesheet = Timesheet.create!(start: sunday.beginning_of_week, finish: sunday.end_of_week)
    timesheet.shifts.create!(start: sunday.in(9.hours), finish: sunday.in(18.hours)) # 9am -> 6pm

    EarningsClassifier.new(timesheet).record!

    expected = <<~EXPECT.strip
      SUNDAY,9.0
    EXPECT
    assert_earnings expected, timesheet
   end

   test "friday overnight into saturday" do
    friday = Time.zone.today.prev_occurring(:friday)
    saturday = friday.advance(days: 1)
    timesheet = Timesheet.create!(start: friday.beginning_of_week, finish: saturday.end_of_week)
    timesheet.shifts.create!(start: friday.in(18.hours), finish: saturday.in(2.hours)) # 6pm -> 2am

    EarningsClassifier.new(timesheet).record!

    expected = <<~EXPECT.strip
      SATURDAY,2.0
      REGULAR_HOURS,6.0
    EXPECT
    assert_earnings expected, timesheet
   end

  test "saturday overnight into sunday" do
    saturday = Time.zone.today.prev_occurring(:saturday)
    sunday = saturday.advance(days: 1)
    timesheet = Timesheet.create!(start: saturday.beginning_of_week, finish: sunday.end_of_week)

    timesheet.shifts.create!(start: saturday.in(18.hours), finish: sunday.in(2.hours)) # 6pm -> 2am

    EarningsClassifier.new(timesheet).record!

    expected = <<~EXPECT.strip
      SATURDAY,6.0
      SUNDAY,2.0
    EXPECT
    assert_earnings expected, timesheet
  end

  test "regular hours, double time, overtime, and meal addon with saturday overnight into sunday hours" do
    date1 = Time.zone.today.prev_occurring(:monday)
    date2 = Time.zone.today.prev_occurring(:monday).advance(days: 1)
    date3 = Time.zone.today.prev_occurring(:monday).advance(days: 2)
    saturday = Time.zone.today.prev_occurring(:saturday)
    sunday = Time.zone.today.prev_occurring(:sunday)
    timesheet = Timesheet.create!(start: date1.beginning_of_week, finish: sunday.end_of_week)
    timesheet.shifts.create!(start: date1.in(9.hours), finish: date1.in(18.hours)) # 9am -> 6pm
    timesheet.shifts.create!(start: date2.in(7.hours), finish: date2.in(21.hours)) # 7am -> 9pm
    timesheet.shifts.create!(start: date3.in(7.hours), finish: date3.in(20.hours)) # 7am -> 8pm
    timesheet.shifts.create!(start: saturday.in(20.hours), finish: sunday.in(5.hours)) # 8pm -> 5am

    EarningsClassifier.new(timesheet).record!

    expected = <<~EXPECT.strip
      OVERTIME,5.0
      REGULAR_HOURS,28.0
      DOUBLE_TIME,3.0
      MEAL_ALLOWANCE,2.0
      SATURDAY,4.0
      SUNDAY,5.0
    EXPECT

    assert_earnings expected, timesheet
  end

  test "database needs optimising" do
    date1 = Time.zone.today.prev_occurring(:monday)
    date2 = Time.zone.today.prev_occurring(:monday).advance(days: 1)
    date3 = Time.zone.today.prev_occurring(:monday).advance(days: 2)
    date4 = Time.zone.today.prev_occurring(:monday).advance(days: 3)
    date5 = Time.zone.today.prev_occurring(:monday).advance(days: 4)
    date6 = Time.zone.today.prev_occurring(:monday).advance(days: 5)
    date7 = Time.zone.today.prev_occurring(:monday).advance(days: 6)

    timesheet = Timesheet.create!(start: date1.beginning_of_week, finish: date1.end_of_week.advance(weeks: 1))

    timesheet.shifts.create!(start: date1.in(9.hours), finish: date1.in(18.hours)) # 9am -> 6pm
    timesheet.shifts.create!(start: date2.in(7.hours), finish: date2.in(21.hours)) # 7am -> 9pm
    timesheet.shifts.create!(start: date3.in(9.hours), finish: date3.in(18.hours)) # 9am -> 6pm
    timesheet.shifts.create!(start: date4.in(9.hours), finish: date4.in(18.hours)) # 9am -> 6pm
    timesheet.shifts.create!(start: date5.in(9.hours), finish: date4.in(18.hours)) # 9am -> 6pm
    timesheet.shifts.create!(start: date6.in(9.hours), finish: date4.in(18.hours)) # 9am -> 6pm
    timesheet.shifts.create!(start: date7.in(9.hours), finish: date4.in(18.hours)) # 9am -> 6pm

    assert_optimized_queries { EarningsClassifier.new(timesheet).record! }
  end

  private

  ##
  # asserts that no N+1s were detected during the block's execution
  #
  def assert_optimized_queries
    assert_nothing_raised { Prosopite.scan { yield } }
  end

  ##
  # makes asserting earning simple! just format them like so:
  #
  #  REGULAR_HOURS,20.0
  #  DOUBLE_TIME,1.0
  #  MEAL_ALLOWANCE,1.0
  #  OVERTIME,2.0
  #
  def assert_earnings(expected, timesheet)
    actual = timesheet.earnings.group_by(&:code).map do |code, earning|
      [code, earning.sum(&:units)].join(",")
    end.join("\n")

    assert_equal expected, actual
  end
end
