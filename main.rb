require_relative 'lib/game'

# Fix za potencijalne probleme s putanjama ako se pokreće iz roota
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))

# Inicijalizacija i pokretanje igre
game = Game.new
game.start
