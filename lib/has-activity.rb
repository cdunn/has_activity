require "active_record"
require "active_support"

$LOAD_PATH.unshift(File.dirname(__FILE__))

module HasActivity
end

require "has_activity/activitize"
require "has_activity/activitize_calculations"
require "has_activity/core"
require "has_activity/graph_ext"

$LOAD_PATH.shift

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend HasActivity::Activitize
  ActiveRecord::Base.send :include, HasActivity::Activitize

  ActiveRecord::Calculations.extend HasActivity::ActivitizeCalculations
  ActiveRecord::Calculations.send :include, HasActivity::ActivitizeCalculations
end
