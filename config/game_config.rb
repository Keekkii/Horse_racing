module GameConfig
  # Simulation Constants
  BASE_SPEED_SCALE = 1.0
  TRACK_LENGTH = 400 # meters, shortened for faster races
  SEGMENT_LENGTH = 50 # meters per segment

  # Stamina
  STAMINA_DRAIN_BASE = 1.0
  RECOVERY_RATE = 0.5
  BOOST_SPEED_MULTIPLIER = 1.2
  DEPLETED_SPEED_MULTIPLIER = 0.6

  # Terrain Modifiers
  # Added :incline for stronger stamina impact and more variance.
  TERRAIN_TYPES = [:grass, :mud, :sand, :gravel, :incline]
  TERRAIN_MODIFIERS = {
    grass:  { speed: 1.0,  stamina_drain: 1.0, injury_chance: 0.002 },
    mud:    { speed: 0.8,  stamina_drain: 1.5, injury_chance: 0.005 },
    sand:   { speed: 0.9,  stamina_drain: 1.3, injury_chance: 0.004 },
    gravel: { speed: 0.95, stamina_drain: 1.1, injury_chance: 0.003 },
    incline:{ speed: 0.92, stamina_drain: 1.7, injury_chance: 0.006 }
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
  # Interpreted as OVERROUND, not "reduce probability".
  # Example: 0.10 -> book sums to 1.10.
  HOUSE_EDGE = 0.10

  # Form
  FORM_RACES_N = 5
  # Newer races are more important (must sum to 1.0)
  FORM_WEIGHTS = [0.35, 0.25, 0.20, 0.12, 0.08]
  # How strongly form affects effective stats (0.20 = ±20% swing approx)
  FORM_IMPACT = 0.20

  # Injury model (used per-tick)
  INJURY_SEVERITY_RANGE = (1..3)
  INJURY_DURATION_RANGE = (2..5)
  # Multipliers applied to base terrain injury chance
  INJURY_STAMINA_LOW_THRESHOLD = 0.25 # below this, risk climbs faster
  INJURY_STAMINA_RISK_MAX = 2.0       # cap stamina-based multiplier
  INJURY_AGE_RISK_PER_YEAR_OVER_PEAK = 0.12
  INJURY_AGE_RISK_PER_YEAR_UNDER_PEAK = 0.06
  RACE_TYPE_INJURY_MULTIPLIERS = {
    "Standard" => 1.0,
    "Championship" => 1.15
  }

  # Championship scoring (configurable)
  CHAMPIONSHIP_POINTS = [5, 3, 1, 0]

    # Championship fatigue carry-over
  CHAMPIONSHIP_STAMINA_RECOVERY = 0.35
  # 0.35 znači: 35% razlike do max_stamina se vrati između utrka

    # Aging
  RACES_PER_YEAR = 5
  MIN_RETIRE_AGE = 8
  FORCED_RETIRE_AGE = 10
  RETIRE_CHANCE_PER_YEAR = 0.25

end
