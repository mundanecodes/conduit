class HealthCheckFlow < Conduit::Flow
  initial_state :check_status

  state :check_status do
    before_render do |session|
      session.data[:checks] = perform_health_checks
    end

    display do |session|
      checks = session.data[:checks]

      text = "System Health Check\n"
      text += "==================\n\n"

      checks.each do |service, status|
        icon = status[:ok] ? "✓" : "✗"
        text += "#{icon} #{service}: #{status[:message]}\n"
      end

      text += "\n1. Refresh\n2. Exit"
      text
    end

    on "1", to: :check_status  # Refresh by going to same state
    on "2" do
      Conduit::Response.new(text: "Health check complete.", action: :end)
    end
  end

  private

  def perform_health_checks
    {
      "Redis" => check_redis,
      "Database" => check_database,
      "Memory" => check_memory,
      "Response Time" => check_response_time
    }
  end

  def check_redis
    start = Time.current
    Conduit.configuration.redis_pool.with { |r| r.ping }
    elapsed = ((Time.current - start) * 1000).round(2)
    {ok: true, message: "Connected (#{elapsed}ms)"}
  rescue => e
    {ok: false, message: "Error: #{e.message}"}
  end

  def check_database
    if defined?(ActiveRecord::Base)
      start = Time.current
      ActiveRecord::Base.connection.active?
      elapsed = ((Time.current - start) * 1000).round(2)
      {ok: true, message: "Connected (#{elapsed}ms)"}
    else
      {ok: true, message: "Not configured"}
    end
  rescue => e
    {ok: false, message: "Error: #{e.message}"}
  end

  def check_memory
    used = `ps -o rss= -p #{Process.pid}`.to_i / 1024
    {ok: used < 500, message: "#{used}MB used"}
  end

  def check_response_time
    # Simple benchmark
    start = Time.current
    1000.times { "test" * 100 }
    elapsed = ((Time.current - start) * 1000).round(2)
    {ok: elapsed < 50, message: "#{elapsed}ms for 1k ops"}
  end
end
