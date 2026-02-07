module GameConfig
  # --- Konstante Simulacije ---
  BASE_SPEED_SCALE = 1.0
  TRACK_LENGTH = 400 # metri, skraćeno za brže utrke
  SEGMENT_LENGTH = 50 # metri po segmentu staze

  # --- Stamina (Izdržljivost) ---
  STAMINA_DRAIN_BASE = 1.0      # Osnovna potrošnja stamine
  RECOVERY_RATE = 0.5           # Stopa oporavka
  BOOST_SPEED_MULTIPLIER = 1.2  # Množitelj brzine kad konj ubrzava
  DEPLETED_SPEED_MULTIPLIER = 0.6 # Množitelj brzine kad je stamina potrošena

  # --- Modifikatori Terena ---
  # Dodan :incline (uzbrdica) za jači utjecaj na staminu i veću varijancu.
  TERRAIN_TYPES = [:grass, :mud, :sand, :gravel, :incline]
  TERRAIN_MODIFIERS = {
    grass:  { speed: 1.0,  stamina_drain: 1.0, injury_chance: 0.002 }, # Trava: neutralna
    mud:    { speed: 0.8,  stamina_drain: 1.5, injury_chance: 0.005 }, # Blato: sporo, umara
    sand:   { speed: 0.9,  stamina_drain: 1.3, injury_chance: 0.004 }, # Pijesak: umjeren utjecaj
    gravel: { speed: 0.95, stamina_drain: 1.1, injury_chance: 0.003 }, # Šljunak
    incline:{ speed: 0.92, stamina_drain: 1.7, injury_chance: 0.006 }  # Uzbrdica: jako umara
  }

  # --- Krivulja Starenja ---
  PEAK_AGE = 4 # Najbolje godine za konja
  AGE_GRAPH = {
    2 => 0.8,
    3 => 0.95,
    4 => 1.0, # Vrhunac forme
    5 => 0.95,
    6 => 0.85,
    7 => 0.7
  }

  # --- Klađenje ---
  # HOUSE_EDGE se koristi kao "Overround" (marža kladionice).
  # Primjer: 0.10 znači da suma vjerojatnosti iznosi 1.10 u korist kuće.
  HOUSE_EDGE = 0.10

  # --- Forma ---
  FORM_RACES_N = 5 # Broj utrka koje se gledaju za formu
  # Novije utrke su važnije (mora se zbrojiti na 1.0)
  FORM_WEIGHTS = [0.35, 0.25, 0.20, 0.12, 0.08]
  # Koliko jako forma utječe na efektivne statistike (0.20 = ±20% promjene)
  FORM_IMPACT = 0.20

  # --- Model Ozljeda (koristi se po "ticku" u simulaciji) ---
  INJURY_SEVERITY_RANGE = (1..3) # Raspon težine ozljede
  INJURY_DURATION_RANGE = (2..5) # Koliko utrka traje oporavak
  # Množitelji koji se primjenjuju na osnovnu šansu za ozljedu terena
  INJURY_STAMINA_LOW_THRESHOLD = 0.25 # Ispod ovoga rizik raste brže
  INJURY_STAMINA_RISK_MAX = 2.0       # Maksimalni množitelj rizika zbog stamine
  INJURY_AGE_RISK_PER_YEAR_OVER_PEAK = 0.12   # Povećanje rizika s godinama iznad vrhunca
  INJURY_AGE_RISK_PER_YEAR_UNDER_PEAK = 0.06  # Rizik za mlade konje
  RACE_TYPE_INJURY_MULTIPLIERS = {
    "Standard" => 1.0,
    "Championship" => 1.15 # Veći rizik u prvenstvu
  }

  # --- Prvenstvo (Bodovanje) ---
  CHAMPIONSHIP_POINTS = [5, 3, 1, 0]

  # --- Prijenos umora u prvenstvu ---
  CHAMPIONSHIP_STAMINA_RECOVERY = 0.35
  # 0.35 znači: 35% razlike do maksimalne stamine se vrati između utrka

  # --- Starenje i Umirovljenje ---
  RACES_PER_YEAR = 5          # Koliko utrka čini jednu godinu života konja
  MIN_RETIRE_AGE = 8          # Minimalna dob za umirovljenje
  FORCED_RETIRE_AGE = 10      # Prisilno umirovljenje
  RETIRE_CHANCE_PER_YEAR = 0.25 # Šansa za umirovljenje svake godine

end
