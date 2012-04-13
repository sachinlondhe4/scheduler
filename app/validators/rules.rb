class Rules < ActiveModel::Validator

  @@max_segs = 4

  def validate(record)
    unless is_week?(record)
      record.errors[:end_at] << 'Segments must be at least 7 days long'
    end

    unless up_to_max_segs?(record)
      record.errors[:segs] << 'You have more than 4 segments. Please add vacation days to an existing segment'
    end

    unless less_than_allowed?(record)
      record.errors[:allowed] << 'You have selected more vacation days than you have accrued'
    end

    unless less_than_max_per_day?(record)
      record.errors[:max_day] << 'You have selected a day that has no more availability'
    end
  end

  # at least one week
  def is_week?(record)
    return calculate_length(record) +1 >= 7
  end

  def up_to_max_segs?(record)
    events = Event.find_all_by_nurse_id(record.nurse_id) # the current one is #4
    if not events
      return true
    else
      return events.length <= @@max_segs-1
    end
  end

  # no more weeks than allowed
  def less_than_allowed?(record)
    num_days_total = record.nurse.num_weeks_off * 7
    num_days_taken = 0
    events = Event.find_all_by_nurse_id(record.nurse_id)
    events.each do |event|
      num_days_taken += calculate_length(event)
    end
    num_days_taken += calculate_length(record)
    return num_days_taken < num_days_total
  end

  def less_than_max_per_day?(record)
    record.nurse.unit.calculate_max_per_day(record.nurse.shift)
    start_date = record.start_at.to_date
    end_date = record.end_at.to_date
    while start_date <= end_date do
      @num_on_this_day = num_nurses_on_day(start_date, record.nurse.shift, record.nurse.unit_id)
      if @num_on_this_day < Unit.max_per[:year]
        start_date = start_date.next_day
      elsif less_than_max_in_additional_month?(start_date)
        start_date = start_date.next_day
      else
        return false
      end
    end
    return true
  end

  def less_than_max_in_additional_month?(start_date)
    max_this_month = 0
    curr_month = start_date.month
    Event.additional_months.each do |month|
      if curr_month == month
      max_this_month += 1
      end
    end
    return @num_on_this_day < Unit.max_per[:year] + max_this_month
  end

  def num_nurses_on_day(start_date, shift, unit_id)
    max_weeks = 6 
    range_buffer = max_weeks * 7

    events = Event.joins(:nurse)
                  .where(
                          'nurses.shift' => shift, 
                          'nurses.unit_id' => unit_id, 
                          'nurses.start_at between ? and ?' => start_date - range_buffer, start_date
                          )

    num_nurses = 0
    events.each do |e|
        if e.start.to_date <= start_date >= e.end_date.to_date
          num_nurses += 1
        end
    end

    return num_nurses
  end

  def calculate_length (event)
    start_at = event.start_at.to_date
    end_at = event.end_at.to_date
    return end_at - start_at
  end

end
