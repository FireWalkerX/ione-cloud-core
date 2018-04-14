module Deferable
    # Defer given block at function
    # @note Remember to make your method deferable
    # @example How to make method deferable
    #   class YourClass
    #       include Deferable
    #       def test_method_with_defer
    #           defer { puts 'prints this after return' }
    #           return
    #       end
    #       deferable :test_method_with_defer
    #   end
    def defer &block
        @defered_methods << block
        return true
    end

    # @!visibility private
    def self.included(mod)
        mod.extend ClassMethods
    end

    # @!visibility private    
    module ClassMethods
        def deferable method
            original_method = instance_method(method)
            define_method(method) do |*args|
                @@defered_method_stack ||= []
                @@defered_method_stack << @defered_methods
                @defered_methods = []
                begin
                    original_method.bind(self).(*args)
                ensure
                    @defered_methods.each {|m| m.call }
                    @defered_methods = @@defered_method_stack.pop
                end
            end
        end
    end
end
