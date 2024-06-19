class DayOfWeekTest < EarningTest
  ##
  # Determines if a shift occurs completely or partially on a specified day of the week
  #
  has_one :day_of_week_test_config
  delegate :wday, to: :day_of_week_test_config

  ##
  # Determines how many hours are applicable
  def hours(ctx)
    shift_hours_within_weekday(ctx)
  end

  ##
  # Determines if there are any hours applicable
  #
  def addon?(ctx)
    shift_hours_within_weekday(ctx) > 0
  end

  private

  def shift_hours_within_weekday(ctx)
    shift_start = ctx.shift.start
    shift_end = ctx.shift.finish
    wday_as_number = DayOfWeekTestConfig.wdays[wday]
    return 0 unless shift_start.wday == wday_as_number || shift_end.wday == wday_as_number

    total_hours = 0
    current_time = shift_start

    while current_time < shift_end
      period_end = end_of_shift_or_day(current_time, shift_end)
      total_hours += hours_in_period(current_time, period_end, wday_as_number)
      current_time = period_end
    end

    total_hours
  end

  def end_of_shift_or_day(current_time, shift_end)
    start_of_next_day = (current_time + 1.day).beginning_of_day
    [start_of_next_day, shift_end].min
  end

  def hours_in_period(current_time, period_end, wday_as_number)
    return 0 unless current_time.wday == wday_as_number

    (period_end - current_time) / 1.hour
  end
end
