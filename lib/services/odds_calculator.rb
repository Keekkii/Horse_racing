require_relative '../models/horse'
require_relative '../../config/game_config'

class OddsCalculator
  def self.calculate(horses)
    total_rating = 0.0
    scores = {}

    horses.each do |horse|
      # Simplified rating formula: speed * stamina * form * age_factor
      rating = horse.effective_speed * (horse.effective_stamina * 0.1)
      rating += rand(0.5..1.0) # Small random variance for "form" or unpredictability
      scores[horse.id] = rating
      total_rating += rating
    end

    odds = {}
    horses.each do |horse|
      probability = scores[horse.id] / total_rating
      # Apply House Edge
      probability_with_vig = probability * (1.0 - GameConfig::HOUSE_EDGE)
      
      # Convert to Decimal Odds (European style)
      if probability_with_vig <= 0
        odds[horse.id] = 999.0 
      else
        odds[horse.id] = (1.0 / probability_with_vig).round(2)
      end
    end
    odds
  end
end
