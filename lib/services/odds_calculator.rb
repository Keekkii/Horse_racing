require_relative '../models/horse'
require_relative '../../config/game_config'

class OddsCalculator
  # Vraća hash sa:
  # {
  #   odds: { horse_id => decimal_odds },
  #   probabilities: { horse_id => fair_probability },
  #   implied_probabilities: { horse_id => probability_with_overround },
  # }
  #
  # - Forma dolazi iz baze via Horse#form_multiplier (nema nasumičnosti).
  # - House edge je implementiran kao OVERROUND: suma(implied) = 1 + HOUSE_EDGE
  def self.calculate(horses, terrain_segments: nil)
    scores = {}

    # Izračun prosječnog utjecaja terena na brzinu i potrošnju stamine
    terrain_speed = 1.0
    terrain_drain = 1.0
    if terrain_segments && !terrain_segments.empty?
      terrain_speed = terrain_segments.map { |s| s[:modifiers][:speed].to_f }.sum / terrain_segments.length
      terrain_drain = terrain_segments.map { |s| s[:modifiers][:stamina_drain].to_f }.sum / terrain_segments.length
    end

    horses.each do |horse|
      stats = horse.effective_stats

      # Brzina je glavni faktor, stamina pomaže održati brzinu
      speed_component = stats[:speed]
      stamina_component = stats[:stamina] * 0.10

      # Prilagodba uloga stamine ovisno o težini terena (terrain_drain)
      stamina_bias = [[(terrain_drain - 1.0) * 0.5, 0.0].max, 0.5].min
      rating = speed_component * (1.0 - stamina_bias) + stamina_component * (1.0 + stamina_bias)

      rating *= terrain_speed
      rating = 0.0001 if rating <= 0
      scores[horse.id] = rating
    end

    # Normalizacija ratinga u vjerojatnosti (sum = 1.0)
    total = scores.values.sum
    fair = {}
    scores.each { |hid, score| fair[hid] = score / total }

    # Primjena marže kladionice (Overround)
    overround = 1.0 + GameConfig::HOUSE_EDGE
    implied = {}
    fair.each { |hid, p| implied[hid] = p * overround }

    # Konverzija vjerojatnosti u decimalne kvote (npr. 0.5 -> 2.0)
    odds = {}
    implied.each do |hid, p|
      odds[hid] = p <= 0 ? 999.0 : (1.0 / p).round(2)
    end

    { odds: odds, probabilities: fair, implied_probabilities: implied }
  end
end
