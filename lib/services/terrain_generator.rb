require_relative '../../config/game_config'

class TerrainGenerator
  def self.generate_terrain(seed)
    rng = Random.new(seed)

    segments = (GameConfig::TRACK_LENGTH / GameConfig::SEGMENT_LENGTH).to_i
    terrain = Array.new(segments) { segment(:grass) } # default grass

    # 3 small patches, each 1-3 segments
    patch_types = [:mud, :sand, :incline, :gravel]
    patches = 3

    patches.times do
      type = patch_types.sample(random: rng)
      length = rng.rand(1..3)
      start = rng.rand(0...(segments - length))
      length.times do |i|
        terrain[start + i] = segment(type)
      end
    end

    terrain
  end

  def self.segment(type)
    { type: type, modifiers: GameConfig::TERRAIN_MODIFIERS[type] }
  end
end
