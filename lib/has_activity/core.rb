module HasActivity
  module Core
    def self.included(base)
      base.send :include, HasActivity::Core::ClassMethods
      base.extend HasActivity::Core::ClassMethods
    end

    module ClassMethods

      def activity_since(*args)
        if ActiveRecord::VERSION::MAJOR == 4
          all.activity_since(*args)
        else
          scoped.activity_since(*args)
        end
      end

      def activity_between(*args)
        if ActiveRecord::VERSION::MAJOR == 4
          all.activity_between(*args)
        else
          scoped.activity_between(*args)
        end
      end

    end # ClassMethods
  end # Core
end # HasActivity
