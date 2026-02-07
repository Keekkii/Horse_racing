require 'sqlite3'
require 'json'

class Database
  DB_FILE = 'db/racing.sqlite'

  # Vraća ili kreira vezu s bazom podataka
  def self.connection
    @db ||= SQLite3::Database.new(DB_FILE)
    @db.results_as_hash = true # Rezultati upita se vraćaju kao Hash
    @db
  end

  # Postavljanje baze: provjera sheme i punjenje početnim podacima ako je prazna
  def self.setup
    puts "Checking database schema..."
    create_tables
    count = connection.get_first_value("SELECT count(*) FROM horses")
    seed_data if count == 0
  end

  # Kreiranje tablica potrebnih za igru
  def self.create_tables
    connection.execute_batch <<-SQL
      CREATE TABLE IF NOT EXISTS horses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        symbol TEXT,
        base_speed REAL,
        stamina_rating REAL,
        acceleration REAL,
        age INTEGER,
        races_run INTEGER DEFAULT 0,
        wins INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS races (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date DATETIME DEFAULT CURRENT_TIMESTAMP,
        race_type TEXT,
        terrain_seed INTEGER,
        winner_id INTEGER
      );

      CREATE TABLE IF NOT EXISTS race_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_id INTEGER,
        horse_id INTEGER,
        position INTEGER,
        finish_time REAL,
        segment_times TEXT, -- JSON array
        FOREIGN KEY(race_id) REFERENCES races(id),
        FOREIGN KEY(horse_id) REFERENCES horses(id)
      );

      CREATE TABLE IF NOT EXISTS injuries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        horse_id INTEGER,
        injury_type TEXT,
        severity INTEGER,
        races_remaining INTEGER,
        FOREIGN KEY(horse_id) REFERENCES horses(id)
      );

      CREATE TABLE IF NOT EXISTS bets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        race_id INTEGER,
        bet_type TEXT,
        amount REAL,
        odds REAL,
        payout REAL,
        horse_id INTEGER, -- Za Win/Place oklade
        horse2_id INTEGER, -- Za Exacta (1. i 2. mjesto)
        selection TEXT, -- JSON za fleksibilne buduće oklade
        FOREIGN KEY(race_id) REFERENCES races(id)
      );
    SQL

    migrate_bets_table!
  end

  # Lagane migracije za postojeće baze (SQLite nema jednostavan ALTER TABLE IF NOT EXISTS)
  def self.migrate_bets_table!
    cols = connection.execute("PRAGMA table_info(bets)").map { |r| r['name'] }
    unless cols.include?('horse2_id')
      connection.execute("ALTER TABLE bets ADD COLUMN horse2_id INTEGER")
    end
    unless cols.include?('selection')
      connection.execute("ALTER TABLE bets ADD COLUMN selection TEXT")
    end
  end

  # Punjenje baze početnim konjima
  def self.seed_data
    puts "Seeding initial horses..."
    horses = [
      ["Thunder",   "T", 8.0, 7.0, 6.0, 3],
      ["Lightning", "L", 9.0, 5.0, 8.0, 3],
      ["Storm",     "S", 7.5, 8.0, 5.5, 4],
      ["Bolt",      "B", 8.5, 6.0, 9.0, 2],
      ["Flash",     "F", 9.5, 4.0, 9.5, 3]
    ]

    stmt = connection.prepare("INSERT INTO horses (name, symbol, base_speed, stamina_rating, acceleration, age) VALUES (?, ?, ?, ?, ?, ?)")
    horses.each { |h| stmt.execute(h) }
    stmt.close
  end
end
