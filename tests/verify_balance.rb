require_relative '../lib/services/race_simulator'
require_relative '../lib/models/horse'
require_relative '../db/database'

# Silence DB output
class Database
  def self.setup; end
end

puts "Simulating 100 races..."

wins = Hash.new(0)
injuries = 0
total_horses_run = 0

horses = Horse.all

100.times do |i|
  # Reset horse stats for the simulation (don't save to DB)
  sim_horses = horses.map do |h|
    h_clone = h.dup
    h_clone.id = h.id # Keep ID
    h_clone
  end
  
  sim = RaceSimulator.new(sim_horses, 1000 + i)
  
  until sim.finished
    sim.step
  end
  
  winner = sim.results.first[:horse]
  wins[winner.name] += 1
  
  if i == 0
    puts "Debug Race 1:"
    sim.results.each do |res|
      h = res[:horse]
      puts "  #{h.name}: Time #{res[:time].round(2)}s | Speed #{h.base_speed} | Acc #{h.acceleration} | Sta #{h.stamina_rating}"
    end
  end
  
  sim.results.each do |res|
    if res[:injured]
      injuries += 1
    end
  end
  
  total_horses_run += sim_horses.size
end

puts "\n--- Results (100 Races) ---"
wins.sort_by { |_, v| -v }.each do |name, count|
  puts "#{name}: #{count} wins"
end

injury_rate = (injuries.to_f / total_horses_run) * 100
puts "\nTotal Injuries: #{injuries}"
puts "Injury Rate per Horse per Race: #{injury_rate.round(2)}%"
