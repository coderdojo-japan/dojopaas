# スマートウェイトのヘルパーモジュール
module SmartWaitHelper
  # エクスポネンシャルバックオフでリソースの準備を待つ
  def wait_for_resource(resource_type, check_block, options = {})
    max_wait_time = options[:max_wait_time] || 300
    phase = options[:phase] || resource_type
    initial_interval = options[:initial_interval] || 1
    max_interval = options[:max_interval] || 32
    
    start_time = Time.now
    wait_intervals = generate_intervals(initial_interval, max_interval)
    interval_index = 0
    check_count = 0
    last_state = nil
    
    puts "\n⏳ Waiting for #{resource_type} (#{phase})..."
    
    loop do
      check_count += 1
      result = check_block.call
      current_state = result[:state]
      elapsed = (Time.now - start_time).round(1)
      
      # 状態変化時のみログ出力
      if current_state != last_state
        puts "[#{elapsed.to_s.rjust(5)}s] State: #{last_state || '(initial)'} → #{current_state} (check ##{check_count})"
        last_state = current_state
      end
      
      # 成功判定
      if result[:ready]
        puts "✅ #{resource_type.capitalize} ready! (#{elapsed}s, #{check_count} API calls)"
        return result[:data]
      end
      
      # エラー判定
      if result[:error]
        puts "❌ #{resource_type.capitalize} error: #{result[:error]}"
        raise result[:error]
      end
      
      # タイムアウト判定
      if elapsed > max_wait_time
        raise "⏱️ Timeout waiting for #{resource_type} after #{max_wait_time}s"
      end
      
      # 待機
      wait_time = wait_intervals[interval_index] || wait_intervals.last
      sleep(wait_time)
      
      # 次の間隔へ
      interval_index += 1 if interval_index < wait_intervals.length - 1
    end
  end
  
  # ディスクの準備を待つ
  def wait_for_disk_available(agent, disk_id, options = {})
    wait_for_resource("disk", -> {
      disk_status = agent.get_disk_status(disk_id)
      availability = disk_status['Disk']['Availability']
      
      {
        state: availability,
        ready: availability == 'available',
        error: availability == 'failed' ? "Disk creation failed" : nil,
        data: disk_status
      }
    }, options)
  end
  
  # サーバーの起動/停止を待つ
  def wait_for_server_status(agent, server_id, target_status, options = {})
    wait_for_resource("server", -> {
      server_status = agent.get_server_power_status(server_id)
      current_status = server_status['Instance']['Status']
      
      {
        state: current_status,
        ready: current_status == target_status,
        error: nil,
        data: server_status
      }
    }, options.merge(phase: "power-#{target_status}"))
  end
  
  private
  
  def generate_intervals(initial, max_val)
    intervals = []
    current = initial
    while current <= max_val
      intervals << current
      current *= 2
    end
    intervals
  end
end

# シンプルな待機メソッド（後方互換性のため）
module SimpleWaitHelper
  def wait_with_timeout(timeout: 60, interval: 5, &block)
    start_time = Time.now
    
    loop do
      result = yield
      return result if result
      
      if Time.now - start_time > timeout
        raise "Timeout after #{timeout} seconds"
      end
      
      sleep(interval)
    end
  end
end