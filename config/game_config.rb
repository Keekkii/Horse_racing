module GameConfig
  # Simulation Constants
  BASE_SPEED_SCALE = 1.0
  TRACK_LENGTH = 200 # meters, shortened for faster races
  SEGMENT_LENGTH = 100 # meters per segment
  
  # Stamina
  STAMINA_DRAIN_BASE = 1.0
  RECOVERY_RATE = 0.5
  BOOST_SPEED_MULTIPLIER = 1.2
  DEPLETED_SPEED_MULTIPLIER = 0.6

  # Terrain Modifiers
  TERRAIN_TYPES = [:grass, :mud, :sand, :gravel]
  TERRAIN_MODIFIERS = {
    grass: { speed: 1.0, stamina_drain: 1.0, injury_chance: 0.01 },
    mud:   { speed: 0.8, stamina_drain: 1.5, injury_chance: 0.03 },
    sand:  { speed: 0.9, stamina_drain: 1.3, injury_chance: 0.02 },
    gravel:{ speed: 0.95, stamina_drain: 1.1, injury_chance: 0.02 }
  }

  # Age Curve
  PEAK_AGE = 4
  AGE_GRAPH = {
    2 => 0.8,
    3 => 0.95,
    4 => 1.0, # Peak
    5 => 0.95,
    6 => 0.85,
    7 => 0.7
  }

  # Betting
  HOUSE_EDGE = 0.1 # 10%
end
