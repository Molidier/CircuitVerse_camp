# frozen_string_literal: true

require "connection_pool"

# Sidekiq 8.0.7 still calls ConnectionPool::TimedStack#pop with a positional
# timeout, while connection_pool 3.x only accepts keyword arguments.
if ConnectionPool::TimedStack.instance_method(:pop).parameters.all? { |kind, _| kind.to_s.start_with?("key") }
  ConnectionPool::TimedStack.prepend(Module.new do
    def pop(timeout_arg = nil, exception: ConnectionPool::TimeoutError, **kwargs)
      timeout = kwargs.delete(:timeout)

      timeout =
        if !timeout_arg.nil?
          timeout_arg
        else
          timeout
        end

      if timeout.nil?
        super(exception: exception, **kwargs)
      else
        super(timeout: timeout, exception: exception, **kwargs)
      end
    end
  end)
end
