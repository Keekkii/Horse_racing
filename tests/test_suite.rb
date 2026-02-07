require 'minitest/autorun'
require_relative '../lib/game'
require_relative '../lib/models/horse'
require_relative '../lib/services/odds_calculator'
require_relative '../lib/services/race_simulator'

class TestHorseRacing < Minitest::Test
  def setup
    # Postavljanje testnog okruženja
    # Brišemo tablice kako bismo imali čisto stanje za svaki test
    Database.setup
    Database.connection.execute("DELETE FROM injuries")
    Database.connection.execute("DELETE FROM race_results")
    Database.connection.execute("DELETE FROM races")
    # Ne brišemo konje jer se seedaju ako fale, ali stvaramo nove instance u testovima.
  end

  def test_odds_calculation
    # Kreiranje dva testna konja
    h1 = Horse.new('id' => 1, 'name' => 'Fast', 'base_speed' => 10.0, 'stamina_rating' => 10.0, 'age' => 3)
    h2 = Horse.new('id' => 2, 'name' => 'Slow', 'base_speed' => 5.0,  'stamina_rating' => 5.0,  'age' => 3)
    
    odds = OddsCalculator.calculate([h1, h2])
    
    # Brži konj trebao bi imati manju kvotu (veću vjerojatnost pobjede)
    assert odds[1] < odds[2], "Faster horse should have lower odds"
  end

  def test_stamina_drain
    h1 = Horse.new('id' => 1, 'name' => 'Runner', 'base_speed' => 10.0, 'stamina_rating' => 100.0, 'age' => 3, 'acceleration' => 5.0)
    sim = RaceSimulator.new([h1])
    
    initial_stamina = sim.get_state(1)[:stamina]
    
    # Pokreni nekoliko koraka simulacije
    10.times { sim.step }
    
    current_stamina = sim.get_state(1)[:stamina]
    assert current_stamina < initial_stamina, "Stamina should drain during race"
  end

  def test_age_curve
    # Dob 4 je vrhunac (Multiplier 1.0)
    young = Horse.new('id' => 1, 'age' => 4, 'base_speed' => 10.0)
    # Dob 7 je u padu (Multiplier 0.7 prema konfiguraciji)
    old   = Horse.new('id' => 2, 'age' => 7, 'base_speed' => 10.0)
    
    assert_in_delta 10.0, young.effective_speed, 0.1
    # 10.0 * 0.7 = 7.0
    assert_in_delta 7.0, old.effective_speed, 0.1
  end
end
