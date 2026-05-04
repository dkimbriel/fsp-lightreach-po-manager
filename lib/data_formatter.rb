# module with helpers for string.data formatting
module DataFormatter
    include ActionView::Helpers::NumberHelper

    def convert_number_to_currency_string(number, precision: 0)
        return '' if number.nil? || number.blank?

        number_to_currency(number, unit: '$', precision: precision)
    end

    def convert_number_to_percent_string(number, precision: 0)
        return '' if number.nil? || number.blank?

        number *= 100
        number_to_percentage(number, precision: precision)
    end

    def convert_to_date_time_str?(date_obj, timezone, format: '%m/%d/%Y %I:%M %p')
        mapped_timezone = convert_timezone(timezone)
        if mapped_timezone.blank? || date_obj.blank?
            return "timezone: #{timezone} or date_obj: #{date_obj} was blank, please alert software to resolve"
        end

        time_in_zone = Time.find_zone(mapped_timezone).parse(date_obj)

        # #this is pretty hacky, but it works for now
        if mapped_timezone != 'America/Chicago' && DateTime.now.month > 3 && DateTime.now.month < 11
            return time_in_zone + 1.hour
        end

        time_in_zone
    end

    def convert_timezone(timezone)
        mapping = {
            'America/New_York' => 'EST',
            'America/Chicago' => 'America/Chicago',
            'US/Mountain' => 'MST',
            'US/Eastern' => 'EST'
        }
        mapping[timezone]
    end

    def convert_unix_to_date_str?(unix_str)
        if unix_str.present?
            Time.at(unix_str.to_i / 1000).to_date.to_time.strftime('%m/%d/%Y')
        else
            ''
        end
    end

    def convert_unix_to_date_obj?(unix_str)
        return unless unix_str.present?

        Time.at(unix_str.to_i / 1000).to_date
    end
end
