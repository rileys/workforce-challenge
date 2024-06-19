class EarningsClassifier
  ##
  # Calculates the earnings of a timesheet's shifts
  #

  attr_reader :timesheet

  def initialize(timesheet)
    @timesheet = timesheet
  end

  ##
  # Traverses a timesheet's shifts recording the earnings
  #
  def record!
    timesheet.shifts.each_with_object(EarningsContext.new(@timesheet)) do |shift, earnings_context|
      shift.earnings.destroy_all
      earnings_context.next!(shift)

      process_hours_rules(shift, earnings_context)
      process_addon_rules(shift, earnings_context)

      shift.save!
    end
  end

  private

  def process_hours_rules(shift, earnings_context)
    hours_rules = HoursRule.ordered_by_rank
    hours_rules.each do |rule|
      break unless earnings_context.remaining_hours?

      applicable_hours = rule.hours(earnings_context).clamp(0, earnings_context.remaining_hours)
      next if applicable_hours <= 0

      shift.earnings.build(earning_rule: rule, units: applicable_hours)
      earnings_context.apply!(applicable_hours)
    end
  end

  def process_addon_rules(shift, earnings_context)
    addon_rules = EarningRule.where.not(type: 'HoursRule')
    addon_rules.each do |rule|
      shift.earnings.build(earning_rule: rule, units: rule.units) if rule.addon?(earnings_context)
    end
  end
end
