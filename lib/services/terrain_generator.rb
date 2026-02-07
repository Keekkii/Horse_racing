require_relative '../../config/game_config'

class TerrainGenerator
  # Generira teren na temelju sjemena (seed) za ponovljivost
  def self.generate_terrain(seed)
    rng = Random.new(seed)

    segments = (GameConfig::TRACK_LENGTH / GameConfig::SEGMENT_LENGTH).to_i
    terrain = Array.new(segments) { segment(:grass) } # Zadano: trava (neutralno)

    # Dodajemo nekoliko "zakrpa" različitog terena (blato, pijesak, uzbrdica...)
    patch_types = [:mud, :sand, :incline, :gravel]
    patches = 3

    patches.times do
      type = patch_types.sample(random: rng)
      length = rng.rand(1..3) # Duljina zakrpe u segmentima
      start = rng.rand(0...(segments - length))
      length.times do |i|
        terrain[start + i] = segment(type)
      end
    end

    terrain
  end

  # Helper za kreiranje segmenta
  def self.segment(type)
    { type: type, modifiers: GameConfig::TERRAIN_MODIFIERS[type] }
  end
end
