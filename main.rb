require_relative 'lib/game'

# Fix for potential path issues if running from root
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))

game = Game.new
game.start
