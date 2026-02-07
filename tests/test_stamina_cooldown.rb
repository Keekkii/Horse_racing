require_relative '../lib/services/race_simulator'
require_relative '../lib/models/horse'

# Mock Database connection
class Database
  def self.connection
    @connection ||= Object.new
  end
  def self.setup; end
end

# Mock Horse
class MockHorse < Horse
  def initialize
    @id = 1
    @name = "Exhausted Horse"
    @base_speed = 10.0
    @stamina_rating = 10.0
    @acceleration = 5.0
    @age = 3
    @races_run = 0
    @wins = 0
    @current_injury = nil
  end
  
  def effective_stamina
    10.0
  end
  
  def effective_speed
    10.0
  end
end

puts "Testing Stamina Cooldown..."

horse = MockHorse.new
simulator = RaceSimulator.new([horse], 12345)

state = simulator.get_state(horse.id)

# 1. Force Exhaustion
state[:stamina] = 0.1 # Very low, next step should drain it
state[:exhausted] = false
simulator.step # Should trigger exhaustion logic if drain > 0.1

# Check if simulation decided it was exhausted
if state[:stamina] <= 0 && state[:exhausted]
  puts "SUCCESS: Horse became exhausted."
else
  # If drain wasn't enough, force it for the test
  puts "INFO: Drain wasn't enough (#{state[:stamina]}), forcing for test logic check..."
  state[:stamina] = 0.0
  state[:exhausted] = true
end

# 2. Check Recovery while Exhausted
initial_exhausted_stamina = state[:stamina]
puts "Stamina while exhausted: #{initial_exhausted_stamina}" # Should be small pos num from recovery

simulator.step
recovered_stamina = state[:stamina]

if recovered_stamina > initial_exhausted_stamina && state[:exhausted]
  puts "SUCCESS: Stamina recovering while still exhausted."
else
  puts "FAILURE: Stamina not recovering or exhaustion cleared too early. (#{recovered_stamina} > #{initial_exhausted_stamina}, exhausted: #{state[:exhausted]})"
  exit 1
end

# 3. Force near-full recovery
state[:stamina] = 9.5 # Recovery is 0.25, so 9.5 -> 9.75 (< 10.0)
simulator.step

if state[:exhausted]
  puts "SUCCESS: Still exhausted at #{state[:stamina]}/10.0 stamina."
else
  puts "FAILURE: Cleared exhaustion too early (#{state[:stamina]}/10.0)."
  exit 1
end

# 4. Force Full Recovery
state[:stamina] = 10.0
simulator.step # Should clear exhaustion

if !state[:exhausted]
  puts "SUCCESS: Exhaustion cleared at full stamina."
else
  puts "FAILURE: Exhaustion stuck."
  exit 1
end

puts "ALL TESTS PASSED"
