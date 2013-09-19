gem 'artoo', '1.1.1'

require 'artoo'
require 'artoo/robot'
require 'pry-nav'
require 'thread'

class Game
  def self.robots
    @robots ||= [
      "/dev/tty.Sphero-OGR-RN-SPP",
      "/dev/tty.Sphero-RYW-RN-SPP",
      "/dev/tty.Sphero-WOY-RN-SPP",
    ].map { |port| SpheroRobot.new(:connections => {:sphero => {:port => port}}) }
  end

  def self.start!
    self.robots.each(&:not_it!)
    self.robots.first.it!
    SpheroRobot.work!(self.robots)
  end

  def self.mutex
    @mutex ||= Mutex.new
  end

  def self.collisions
    @collisions ||= []
  end

  def self.it
    @it ||= robots.first
  end

  def self.it(it)
    @it = it
  end

  def self.collision(robot)
    puts "collision! #{robot.inspect} #{Time.now}"
    if mutex.try_lock
      other, _ = collisions.find { |r,t| r != robot && ((Time.now - t).abs < 1) }
      if other
        if other.it
          robot.it!
          other.not_it!
          collisions.clear
        elsif robot.it
          other.it!
          robot.not_it!
          collisions.clear
        else
          collisions << [robot, Time.now]
        end
      else 
        collisions << [robot, Time.now]
      end
      mutex.unlock
    else
      collisions << [robot, Time.now]
    end
  end
end

class SpheroRobot < Artoo::Robot
  connection :sphero, :adaptor => :sphero
  device :sphero, :driver => :sphero

  def contact(*args)
    Game.collision(self)
  end

  def it!
    puts "#{self} is it!"
    @it = true
    sphero.set_color(:red)
  end

  def not_it!
    puts "#{self} is NOT it!"
    @it = false
    sphero.set_color(:blue)
  end

  attr_accessor :it

  work do
    on sphero, :collision => :contact

    @direction = 0

    every(3.seconds) do
      sphero.roll(80, @direction = ((@direction + 180 + rand(45)) % 360))
    end
  end
end


Game.start!