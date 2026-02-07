require_relative '../lib/services/race_simulator'
require_relative '../lib/models/horse'

# Mock Database connection (Izbjegavanje ovisnosti o pravoj bazi tijekom testa)
class Database
  def self.connection
    @connection ||= Object.new
  end
  def self.setup; end
end

# Mock Horse (Lažni konj)
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

# Prisilno postavljanje stamine na 0
state = simulator.get_state(horse.id)
state[:stamina] = 0.0

puts "Initial Stamina: #{state[:stamina]}"

# Izvrši jedan korak simulacije
simulator.step

# Provjera je li se stamina povećala (regeneracija)
new_stamina = state[:stamina]
puts "Stamina after 1 step (recovery): #{new_stamina}"

if new_stamina > 0.0
  puts "SUCCESS: Stamina regenerated."
else
  puts "FAILURE: Stamina did not regenerate."
  exit 1
end

# Provjera limita (Cap)
# Testiramo da se stamina ne regenerira iznad maksimuma.
# Postavljamo konja s jako malom maksimalnom staminom za ovaj test.

def horse.effective_stamina
  0.1
end

state[:stamina] = -0.1 # Osiguravamo da ulazimo u blok za regeneraciju
simulator.step
capped_stamina = state[:stamina]
puts "Stamina after cap check (Max=0.1): #{capped_stamina}"

if capped_stamina <= 0.10001 # Tolerancija za float brojeve
  puts "SUCCESS: Stamina capped at max."
else
  puts "FAILURE: Stamina exceeded max: #{capped_stamina}"
  exit 1
end
