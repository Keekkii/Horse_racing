require 'minitest/autorun'
require_relative '../lib/game'
require_relative '../lib/models/horse'
require_relative '../lib/services/odds_calculator'
require_relative '../lib/services/race_simulator'

class TestHorseRacing < Minitest::Test
  def setup
    # Setup in-memory DB or rollback transaction?
    # For now, we will test logic that doesn't depend on DB if possible, or use a test DB.
    # To avoid messing with real DB, we can mock or just accept it for this simple script.
    Database.setup
    # Clear tables to ensure clean state
    Database.connection.execute("DELETE FROM injuries")
    Database.connection.execute("DELETE FROM race_results")
    Database.connection.execute("DELETE FROM races")
    # Don't delete horses as they are seeded in setup if missing, but we create new instances for tests anyway.
  end

  def test_odds_calculation
    # Create two dummy horses
    h1 = Horse.new('id' => 1, 'name' => 'Fast', 'base_speed' => 10.0, 'stamina_rating' => 10.0, 'age' => 3)
    h2 = Horse.new('id' => 2, 'name' => 'Slow', 'base_speed' => 5.0,  'stamina_rating' => 5.0,  'age' => 3)
    
    odds = OddsCalculator.calculate([h1, h2])
    
    # Fast horse should have lower odds (higher probability)
    assert odds[1] < odds[2], "Faster horse should have lower odds"
  end

  def test_stamina_drain
    h1 = Horse.new('id' => 1, 'name' => 'Runner', 'base_speed' => 10.0, 'stamina_rating' => 100.0, 'age' => 3, 'acceleration' => 5.0)
    sim = RaceSimulator.new([h1])
    
    initial_stamina = sim.get_state(1)[:stamina]
    
    # Run a few steps
    10.times { sim.step }
    
    current_stamina = sim.get_state(1)[:stamina]
    assert current_stamina < initial_stamina, "Stamina should drain during race"
  end

  def test_age_curve
    # Age 4 is Peak (1.0)
    young = Horse.new('id' => 1, 'age' => 4, 'base_speed' => 10.0)
    # Age 7 is 0.7 in config.
    old   = Horse.new('id' => 2, 'age' => 7, 'base_speed' => 10.0)
    
    assert_in_delta 10.0, young.effective_speed, 0.1
    # 10.0 * 0.7 = 7.0
    assert_in_delta 7.0, old.effective_speed, 0.1
  end
end
