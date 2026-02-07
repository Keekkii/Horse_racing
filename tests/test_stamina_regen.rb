require_relative '../lib/services/race_simulator'
require_relative '../lib/models/horse'

# Mock Database connection to avoid dependency on actual DB during this specific test
class Database
  def self.connection
    @connection ||= Object.new
  end
  def self.setup; end
end

# Mock Horse to avoid DB calls
class MockHorse < Horse
  def initialize
    @id = 1
    @name = "Test Horse"
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

puts "Testing Stamina Regeneration..."

horse = MockHorse.new
simulator = RaceSimulator.new([horse], 12345)

# Force stamina to 0
state = simulator.get_state(horse.id)
state[:stamina] = 0.0

puts "Initial Stamina: #{state[:stamina]}"

# Run one step
simulator.step

# Check if stamina increased
new_stamina = state[:stamina]
puts "Stamina after 1 step (recovery): #{new_stamina}"

if new_stamina > 0.0
  puts "SUCCESS: Stamina regenerated."
else
  puts "FAILURE: Stamina did not regenerate."
  exit 1
end

# Check cap
# To test the cap in the regeneration block, we need stamina <= 0 BUT resulting stamina > max_stamina
# So we need a horse with very low max stamina for this specific check, or assume recovery is large.
# Since recovery is 0.25 (0.5 * 0.5), we can set a temporary override on the horse.

def horse.effective_stamina
  0.1
end

state[:stamina] = -0.1 # Ensure we enter the <= 0 block
simulator.step
capped_stamina = state[:stamina]
puts "Stamina after cap check (Max=0.1): #{capped_stamina}"

if capped_stamina <= 0.10001 # Float tolerance
  puts "SUCCESS: Stamina capped at max."
else
  puts "FAILURE: Stamina exceeded max: #{capped_stamina}"
  exit 1
end
