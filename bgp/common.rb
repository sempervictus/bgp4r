#    This file is part of BGP4R.
#
#    BGP4R is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    BGP4R is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

require 'ipaddr'
require 'logger'

class IPAddr
  alias encode hton

  def self.create(arg)
    if arg.is_a?(String) and arg.is_packed?
      IPAddr.new_ntoh(arg)
    elsif arg.is_a?(Integer)
      IPAddr.new_ntoh([arg].pack('N'))
    elsif arg.is_a?(Array) and arg[0].is_a?(Integer)
      IPAddr.new_ntoh([arg].pack('C*'))
    else
      IPAddr.new(arg)
    end
  end

  def mlen
    @_jme_mlen_ ||= _mlen_
  end

  def _generate_network_inc_
    max_len =  ipv4? ? 32 : 128
    proc { |n| n * (2**(max_len - mlen)) }
  end

  def +(other)
    [IPAddr.create(to_i + other).to_s, mlen].join('/')
  end

  def increment
    @increment ||= _generate_network_inc_
  end

  def ^(other)
    x = to_i + increment.call(other)
    if ipv4?
      [IPAddr.create(x).to_s, mlen].join('/')
    else
      y = [(format '%032x', x)].pack('H*')
      [IPAddr.new_ntoh(y).to_s, mlen].join('/')
    end
  end

  private :_generate_network_inc_

  def netmask
    if ipv4?
      [@mask_addr].pack('N').unpack('C4').collect { |x| x.to_s }.join('.')
    else
      @mask_addr.to_s(16).scan(/..../).collect { |x| x }.join(':')
    end
  end

  private

  def _mlen_
    m = @mask_addr
    len = ipv6? ? 128 : 32
    loop do
      break if m & 1 > 0

      m >>= 1
      len += -1
    end
    len
  end
end

module ::BGP
  module ToShex
    def to_shex(*args)
      respond_to?(:encode) ? encode(*args).unpack('H*')[0] : ''
    end
    alias to_s_hexlify to_shex
    def to_shex4(*args)
      respond_to?(:encode4) ? encode4(*args).unpack('H*')[0] : ''
    end

    def to_shex_len(len, *args)
      s = to_shex(*args)
      "#{s[0..len]}#{s.size > len ? '...' : ''}"
    end

    def to_shex4_len(len, *args)
      s = to_shex4(*args)
      "#{s[0..len]}#{s.size > len ? '...' : ''}"
    end
  end
end

class Array
  alias old_pack pack
  def pack(*args)
    s = old_pack(*args)
    s.instance_eval { @__is_packed__ = true }
    s
  end
end

class String
  def is_packed?
    defined?(@__is_packed__) and @__is_packed__
  end

  def is_packed
    @__is_packed__ = true
    self
  end
  alias packed? :is_packed?

  def hexlify
    return self unless is_packed? or size == 0

    l = 0
    n = 0
    ls = ['']
    s = dup
    while s.size > 0
      l = s.slice!(0, 16)
      ls << format('0x%4.4x:  %s', n, l.unpack("n#{l.size / 2}").collect { |x| format('%4.4x', x) }.join(' '))
      n += 1
    end
    if l.size % 2 > 0
      ns = l.size > 1 ? 1 : 0
      ls.last << if RUBY_VERSION.split('.').join[0, 2] > '18'
                   format('%s%2.2x', ' ' * ns, l[-1].unpack('C')[0])
                 else
                   format('%s%2.2x', ' ' * ns, l[-1])
                 end
    end
    ls
  end
end

class Log < Logger
  private_class_method :new
  @@logger = nil
  def initialize(s)
    super(s)
    @@time = Time.now
    self.datetime_format = '%M:%S'
    self.level = Logger::INFO
  end

  def self.time_reset
    @time = Time.now
  end

  def self.create(s = STDERR)
    @@logger ||= new(s)
  end

  def self.set_filename(s)
    @@logger = new(s)
  end

  def self.level=(level)
    return unless (0..4).include?(level)

    @@logger.level = (level)
  end

  def self.level
    case @@logger.level
    when Logger::INFO then  "(#{Logger::INFO}) 'INFO'"
    when Logger::DEBUG then "(#{Logger::DEBUG}) 'DEBUG'"
    when Logger::WARN then  "(#{Logger::WARN}) 'WARN'"
    when Logger::ERROR then "(#{Logger::ERROR}) 'ERROR'"
    when Logger::FATAL then "(#{Logger::FATAL}) 'FATAL'"
    end
  end

  def self.clear
    `rm #{Log.filename}`
    Log.set_filename(Log.filename)
  end

  def self.filename
    @@logger.instance_eval { @logdev.filename }
  end

  def self.start(*arg)
    Log.create(*arg)
  end

  def self.info(txt)
    @@logger.info(txt) unless @@logger.nil?
  end

  def self.fatal(txt)
    @@logger.fatal(txt) unless @@logger.nil?
  end

  def self.error(txt)
    @@logger.error(txt) unless @@logger.nil?
  end

  def self.debug(txt)
    @@logger.debug(txt) unless @@logger.nil?
  end

  def self.warn(txt)
    @@logger.warn(txt) unless @@logger.nil?
  end

  def self.<<(txt)
    elapsed = Time.now - @@time
    @@logger << "<< #{format '%4.6f', elapsed}: #{txt}\n" unless @@logger.nil?
  end

  def self.>>(txt)
    elapsed = Time.now.to_f - @@time.to_f
    @@logger << ">> #{format '%4.6f', elapsed}: #{txt}\n" unless @@logger.nil?
  end
end
