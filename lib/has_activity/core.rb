module HasActivity
  module Core
    def self.included(base)
      base.send :include, HasActivity::Core::ClassMethods
      base.extend HasActivity::Core::ClassMethods
    end

    module ClassMethods

      def activity_since(*args)
        scoped.activity_since(*args)
      end

      def activity_between(*args)
        scoped.activity_between(*args)
      end

    end # ClassMethods
  end # Core
end # HasActivity
