require_relative '../../config/game_config'

class TerrainGenerator
  def self.generate_terrain(seed, length = GameConfig::TRACK_LENGTH)
    segments = []
    
    # Simple deterministic generation using seed
    rng = Random.new(seed)
    
    # Break track into fixed segments
    num_segments = (length / GameConfig::SEGMENT_LENGTH).ceil
    
    num_segments.times do |i|
      type = GameConfig::TERRAIN_TYPES.sample(random: rng)
      modifier = GameConfig::TERRAIN_MODIFIERS[type]
      
      segments << {
        index: i,
        type: type,
        length: GameConfig::SEGMENT_LENGTH,
        modifiers: modifier
      }
    end
    
    segments
  end
end
