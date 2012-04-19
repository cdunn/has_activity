module HasActivity
  module Activitize
    def activitized?
      false
    end

    ##
    # Give a model activity methods
    #
    # @param [Hash]
    #
    # Example:
    #   class User < ActiveRecord::Base
    #     has_activity :on => :created_at
    #   end
    def has_activity(options={})
      options[:on] ||= :created_at
      activitize(options)
    end
    
    private
    
      def activitize(options={})
        if activitized?
        else
          class_attribute :has_activity_options
          self.has_activity_options = options
        
          class_eval do

            def self.activitized?
              true
            end

            include HasActivity::Core

          end
        end
      end

  end
end
