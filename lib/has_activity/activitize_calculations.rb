module HasActivity
  module ActivitizeCalculations
    def self.included(base)
      base.send :include, HasActivity::ActivitizeCalculations::OverallMethods
      base.extend HasActivity::ActivitizeCalculations::OverallMethods
    end

    module OverallMethods

      def activity_between(between_start, between_end, options={})
        # Normalize dates...
        start_and_end = [between_start.to_time, between_end.to_time]
        if between_start > between_end
          start_and_end = start_and_end.reverse
        end
        calculate_activity(*start_and_end, options.merge(:between => true))
      end

      def activity_since(since, options={})
        calculate_activity(since.to_time, Time.now, options)
      end

      private

      # Grabs a hash of the activity since <time ago> grouped by <hour/day/week>
      # 
      #   * :padding
      #       true/false
      #   * :by
      #       :hour, :day, :week
      #   * :order
      #       :asc, :desc
      #   * :count_on
      #       default is "*". optionally put a custom aggregator ex "table.field".
      #   * :count_distinct
      #       default is false. optionally set to true for distinct counts on :count_on ex. "COUNT(DISTINCT table.field)".
      #   * :sum_on
      #       default is to :count_on. optionally put a custom aggregator ex "table.field" which will "SUM(table.field)"
      #       instead of COUNT.
      # 
      def calculate_activity(between_start, between_end, options={})
        options[:padding] ||= true
        options[:order] ||= :asc
        options[:by] ||= :hour
        options[:on] ||= has_activity_options[:on]
        options[:count_on] ||= "*"
        #options[:sum_on] ||= ""
        options[:count_distinct] = false unless options[:count_distinct]

        # TODO: check for index on :on column

        # Verify user ain't gettin cray...
        # TODO: review other possibilities for people to screw up the query...
        raise "You cannot use custom #group filters with #activity_since" if self.group_values.present?

        activity_column = parse_activity_column(options[:on])
        if options[:sum_on]
          aggregate_column = "SUM(#{parse_activity_column(options[:sum_on])})"
        else
          aggregate_column = parse_activity_column(options[:count_on])
          aggregate_column = "DISTINCT(#{aggregate_column})" if options[:count_distinct]
          aggregate_column = "COUNT(#{aggregate_column})"
        end

        activity_end_time = "'#{between_end.to_s(:db)}'"

        case options[:by].to_s
        when "hour"
          relation = self.select("
            #{activity_column} AS has_activity_timestamp,
            #{aggregate_column} AS has_activity_count,
            ((((YEAR(#{activity_end_time}) - YEAR(#{activity_column}))*365)+(DAYOFYEAR(#{activity_end_time})-DAYOFYEAR(#{activity_column})))*24)+(HOUR(#{activity_end_time})-HOUR(#{activity_column})) AS has_activity_hours_ago,
            CONCAT(YEAR(#{activity_column}), CONCAT(DAYOFYEAR(#{activity_column}), HOUR(#{activity_column}))) AS has_activity_uniqueness
          ")
          unit = "hours"
          oldest_possible_unit = ((between_end-between_start)/60)/60
        when "day"
          relation = self.select("
            #{activity_column} AS has_activity_timestamp,
            #{aggregate_column} AS has_activity_count,
            DATEDIFF(#{activity_end_time}, #{activity_column}) AS has_activity_days_ago,
            CONCAT(YEAR(#{activity_column}), CONCAT(DAYOFYEAR(#{activity_column}))) AS has_activity_uniqueness
          ")
          unit = "days"
          oldest_possible_unit = (((between_end-between_start)/60)/60)/24
        when "week"
          relation = self.select("
            #{activity_column} AS has_activity_timestamp,
            #{aggregate_column} AS has_activity_count,
            ((YEAR(#{activity_end_time}) - YEAR(#{activity_column}))*52)+(WEEK(#{activity_end_time})-WEEK(#{activity_column})) AS has_activity_weeks_ago,
            YEARWEEK(#{activity_column}) AS has_activity_uniqueness
          ")
          unit = "weeks"
          oldest_possible_unit = ((((between_end-between_start)/60)/60)/24)/7
        when "month"
          relation = self.select("
            #{activity_column} AS has_activity_timestamp,
            #{aggregate_column} AS has_activity_count,
            ((YEAR(#{activity_end_time}) - YEAR(#{activity_column}))*12)+(MONTH(#{activity_end_time})-MONTH(#{activity_column})) AS has_activity_months_ago,
            CONCAT(YEAR(#{activity_column}), CONCAT(MONTH(#{activity_column}))) AS has_activity_uniqueness
          ")
          unit = "months"
          oldest_possible_unit = (between_end.year*12+between_end.month) - (between_start.year*12+between_start.month)
        else
          raise "Invalid option :by (:hour, :day, :week, :month)"
        end

        if options[:between]
          relation = relation.where("#{activity_column} BETWEEN ? AND ?", between_start, between_end)
        else
          relation = relation.where("#{activity_column} > ?", between_start)
        end
        relation = relation.group("has_activity_uniqueness").order("#{activity_column} ASC")
        results = connection.select_all(relation.to_sql)

        (options[:padding] ? pad_activity_results(results, between_end, unit, oldest_possible_unit.round, options[:order]) : format_activity_results(results, unit, order))
      end

      def format_activity_results(results, unit, order)
        results.inject([]) do |rs,r|
          entry = {
            :offset   => r["has_activity_#{unit}_ago"].to_i,
            :activity => r["has_activity_count"].to_i,
            :date     => round_activity_timestamp(r["has_activity_timestamp"].is_a?(String) ? Time.parse(r["has_activity_timestamp"]) : r["has_activity_timestamp"], unit)
          }
          (order.to_s == "asc") ? rs.push(entry) : rs.unshift(entry)
        end
      end
      
      def pad_activity_results(results, between_end, unit, oldest_possible_offset, order)
        padded_results = []
        
        current_unit_offset = oldest_possible_offset
        current_result_index = 0
        
        while current_unit_offset >= 0 do
          if current_result_index < results.count && results[current_result_index]["has_activity_#{unit}_ago"].to_i == current_unit_offset
            entry = {
              :offset    => current_unit_offset,
              :activity  => results[current_result_index]["has_activity_count"].to_i,
              :timestamp => round_activity_timestamp(results[current_result_index]["has_activity_timestamp"].is_a?(String) ? Time.parse(results[current_result_index]["has_activity_timestamp"]) : results[current_result_index]["has_activity_timestamp"], unit)
            }
            current_result_index = current_result_index+1
          else
            case unit
            when "hours"
              created_at_given_offset = between_end-current_unit_offset.hours
            when "days"
              created_at_given_offset = between_end-current_unit_offset.days
            when "weeks"
              created_at_given_offset = between_end-current_unit_offset.weeks
            when "months"
              created_at_given_offset = between_end-current_unit_offset.months
            else
              raise "Invalid unit"
            end
            entry = {
              :offset    => current_unit_offset,
              :activity  => 0,
              :timestamp => round_activity_timestamp(created_at_given_offset, unit)
            }
          end
          current_unit_offset = current_unit_offset-1
          (order.to_s == "asc") ? padded_results.push(entry) : padded_results.unshift(entry)
        end
        
        padded_results
      end # pad_activity_results

      def parse_activity_column(col)
        if col.is_a?(String)
          return "*" if col == "*" # Do not quote '*'
          # insert raw...
          activity_column = col.split(".").collect { |v|
            connection.quote_column_name(v)
          }.join(".")
        else
          activity_table_name = connection.quote_table_name(self.table.name)
          activity_column_name = connection.quote_column_name(col)
          activity_column = "#{activity_table_name}.#{activity_column_name}"
        end
        activity_column
      end # parse_activity_column

      def round_activity_timestamp(t, round_to)
        #Time.at((t.to_f / 1.send(round_to)).floor * 1.send(round_to))
        if round_to == "weeks"
          day = t.beginning_of_week.day
        else
          day = t.day
        end

        Time.new(t.year, t.month, (%w(weeks days hours).include?(round_to) ? day : 1), (round_to == "hours" ? t.hour : 0), 0, 0, Time.zone.utc_offset)
      end # round_activity_timestamp
    
    end # OverallMethods
  end # ActivitizeCalculations
end # HasActivity
